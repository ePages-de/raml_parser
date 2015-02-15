require 'raml_parser/yaml_helper'
require 'raml_parser/model'

module RamlParser
  class Parser
    attr_reader :path, :root

    def initialize(options = {})
      @options = {
          :semantic_error => :error,
          :key_unknown => :error,
          :not_yet_supported => :warning
      }.merge(options)
    end

    def parse_file(path)
      node = YamlNode.new(nil, 'root', YamlHelper.read_yaml(path))
      parse_root(node)
    end

    def parse_file_with_marks(path)
      node = YamlNode.new(nil, 'root', YamlHelper.read_yaml(path))
      node.mark_all(:unused)
      node.mark(:used)
      root = parse_root(node)
      { :root => root, :marks => node.marks }
    end

    private

    def parse_root(node)
      root = Model::Root.new
      root.title = node.hash('title').or_default('').value
      root.base_uri = node.hash('baseUri').or_default('').value
      root.version = node.hash('version').value
      root.media_type = node.hash('mediaType').value
      root.secured_by = node.hash('securedBy').or_default([]).array_map { |n| n.value }
      root.documentation = node.hash('documentation').array_map { |n| parse_documenation(n) }
      root.security_schemes = node.hash('securitySchemes').arrayhash_map { |n| parse_security_scheme(n) }
      root.resource_types = node.hash('resourceTypes').mark_all(:used).arrayhash_map { |n| n }
      root.traits = node.hash('traits').mark_all(:used).arrayhash_map { |n| n }

      root.resources = traverse_resources(node, nil) do |n,parent|
        parent_absolute_uri = parent != nil ? parent.absolute_uri : root.base_uri || ''
        parent_relative_uri = parent != nil ? parent.relative_uri : ''
        parent_uri_parameters = parent != nil ? parent.uri_parameters.clone : {}
        parse_resource(n, root, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, false)
      end

      root
    end

    def parse_resource(node, root, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, as_resource_type)
      def extract_uri_parameters(relative_uri)
        names = relative_uri.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first }
        Hash[names.map { |name| [name, Model::NamedParameter.new(name, 'string', name)] }]
      end

      node = node.or_default({})
      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.display_name = node.hash('displayName').value
      resource.description = node.hash('description').value
      resource.uri_parameters = extract_uri_parameters(node.key).merge(parent_uri_parameters.merge(node.hash('uriParameters').hash_map { |n| parse_named_parameter(n) }))
      resource.type = parse_type(node.hash('type'))
      resource.is = parse_is(node.hash('is'))
      resource.secured_by = (root.secured_by + node.hash('securedBy').or_default([]).array_map { |n| n.value }).uniq

      for m in %w(get post put delete head patch options trace connect) do
        if node.value.has_key? m
          resource.methods[m] = parse_method(node.hash(m), root, resource, as_resource_type)
        end
      end

      unless as_resource_type
        resource = mixin_resource_types(node, root, resource)
        resource.display_name = resource.relative_uri unless resource.display_name
      end

      resource
    end

    def parse_method(node, root, resource, as_trait)
      node = node.or_default({})
      method = Model::Method.new(node.key.upcase)
      method.display_name = node.hash('displayName').value
      method.description = node.hash('description').value
      method.query_parameters = node.hash('queryParameters').hash_map { |n| parse_named_parameter(n) }
      method.bodies = node.hash('body').hash_map { |n| parse_body(n) }
      method.responses = node.hash('responses').hash_map { |n| parse_response(n) }
      method.headers = node.hash('headers').hash_map { |n| parse_named_parameter(n) }
      method.secured_by = (resource.secured_by + node.hash('securedBy').or_default([]).array_map { |n| n.value }).uniq if resource
      method.is = parse_is(node.hash('is'))

      unless as_trait
        method = mixin_traits(node, root, method, resource)
        method.display_name = method.method + ' ' + resource.relative_uri unless method.display_name
      end

      method
    end

    def parse_response(node)
      node = node.or_default({})
      response = Model::Response.new(node.key)
      response.display_name = node.hash('displayName').value
      response.description = node.hash('description').value
      response.bodies = node.hash('body').hash_map { |n| parse_body(n) }
      response.headers = node.hash('headers').hash_map { |n| parse_named_parameter(n) }
      response
    end

    def parse_named_parameter(node)
      if node.value.is_a? Array
        # TODO: Not yet supported named parameters with multiple types
        return Model::NamedParameter.new(node.key)
      end

      node = node.or_default({})
      named_parameter = Model::NamedParameter.new(node.key)
      named_parameter.type = node.hash('type').or_default('string').value
      named_parameter.display_name = node.hash('displayName').or_default(named_parameter.name).value
      named_parameter.description = node.hash('description').value
      named_parameter.required = node.hash('required').or_default(true).value
      named_parameter.default = node.hash('default').value
      named_parameter.example = node.hash('example').value
      named_parameter.min_length = node.hash('minLength').value
      named_parameter.max_length = node.hash('maxLength').value
      named_parameter.minimum = node.hash('minimum').value
      named_parameter.maximum = node.hash('maximum').value
      named_parameter.repeat = node.hash('repeat').value
      named_parameter.enum = node.hash('enum').or_default([]).array_map { |n| n.value }
      named_parameter.pattern = node.hash('pattern').value
      named_parameter
    end

    def parse_body(node)
      node = node.or_default({})
      body = Model::Body.new(node.key)
      body.example = node.hash('example').value
      body.schema = node.hash('schema').value
      body.form_parameters = node.hash('formParameters').hash_map { |n| parse_named_parameter(n) }
      # TODO: Form parameters are only allowed for media type application/x-www-form-urlencoded or multipart/form-data
      body
    end

    def parse_security_scheme(node)
      node = node.or_default({})
      security_scheme = Model::SecurityScheme.new(node.key)
      security_scheme.type = node.hash('type').value
      security_scheme.description = node.hash('description').value
      security_scheme.described_by = node.hash('describedBy').value
      security_scheme.settings = node.hash('settings').mark_all(:used).value
      security_scheme
    end

    def parse_documenation(node)
      node = node.or_default({})
      documentation = Model::Documentation.new
      documentation.title = node.hash('title').value
      documentation.content = node.hash('content').value
      documentation
    end

    def parse_type(node)
      node = node.or_default({}).mark_all(:used)
      result = {}
      if node.value.is_a? String
        result = { node.value => nil }
      elsif node.value.is_a? Hash
        result = node.value
      else
        error(:semantic_error, node, 'Invalid type format')
      end
      result
    end

    def parse_is(node)
      node = node.or_default({}).mark_all(:used)
      result = {}
      node.value.each { |n|
        if n.is_a? String
          result = result.merge({ n => nil })
        elsif n.is_a? Hash
          result = result.merge(n)
        else
          error(:key_unknown, node, 'Invalid is format')
        end
      }
      result
    end

    def mixin_resource_types(node, root, resource)
      result = Model::Resource.new(nil, nil)
      resource.type.each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s
        })
        resource_type = root.resource_types.has_key?(name) ? parse_resource(resolve_parametrization(root.resource_types[name], params), root, '', '', {}, true) : nil
        if resource_type != nil
          result = Model::Resource.merge(result, resource_type)
        else
          error(:key_unknown, node, "Importing unknown resource type #{name}")
        end
      end

      Model::Resource.merge(result, resource)
    end

    def mixin_traits(node, root, method, resource)
      result = Model::Method.new(nil)
      (resource.is.merge(method.is)).each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s,
            'methodName' => method.method.downcase
        })
        trait = root.traits.has_key?(name) ? parse_method(resolve_parametrization(root.traits[name], params), root, nil, true) : nil
        if trait != nil
          result = Model::Method.merge(result, trait)
        else
          error(:key_unknown, node, "Importing unknown trait #{name}")
        end
      end

      Model::Method.merge(result, method)
    end

    def resolve_parametrization(node, params)
      require 'active_support/core_ext/string/inflections'

      def alter_string(str, params, node)
        str.gsub(/<<([a-zA-Z]+)(\s*\|\s*!([a-zA-Z_\-]+))?>>/) do |a,b|
          case $3
            when nil
              params[$1].to_s
            when 'singularize'
              params[$1].to_s.singularize
            when 'pluralize'
              params[$1].to_s.pluralize
            else
              error(:key_unknown, node, "Unknown parameter pipe function '#{$3}'")
          end
        end
      end

      def traverse(raw, params, node)
        if raw.is_a? Hash
          Hash[raw.map { |k,v| [traverse(k, params, node), traverse(v, params, node)] }]
        elsif raw.is_a? Array
          raw.map { |i| traverse(i, params, node) }
        elsif raw.is_a? String
          alter_string(raw, params, node)
        else
          raw
        end
      end

      YamlNode.new(node.parent, node.key, traverse(node.value, params, node))
    end

    def traverse_resources(node, parent_resource, &code)
      node.hash_map { |n|
        if n.key =~ /^\//
          resource = code.call(n, parent_resource)
          [resource] + traverse_resources(n, resource, &code)
        else
          []
        end
      }.values.flatten
    end

    def error(type, node, message)
      message = "#{node.path}: #{message}"
      case @options[type]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end

    def not_yet_supported(node, what)
      error(:not_yet_supported, node, "Not yet supported #{what}")
    end
  end
end
