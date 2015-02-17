require 'raml_parser/yaml_helper'
require 'raml_parser/model'

module RamlParser
  class Parser
    def self.parse_file(path)
      ensure_raml_0_8(path)
      node = YamlNode.new(nil, 'root', YamlHelper.read_yaml(path))
      parse_root(node)
    end

    def self.parse_file_with_marks(path)
      ensure_raml_0_8(path)
      node = YamlNode.new(nil, 'root', YamlHelper.read_yaml(path))
      node.mark_all(:unused)
      node.mark(:used)
      root = parse_root(node)
      { :root => root, :marks => node.marks }
    end

    private

    def self.ensure_raml_0_8(path)
      first_line = File.open(path) { |f| f.readline }.strip
      raise "File #{path} does not start with RAML 0.8 comment" unless first_line == '#%RAML 0.8'
    end

    def self.parse_root(node)
      root = Model::Root.new
      root.title = node.hash('title').or_default('').value
      root.version = node.hash('version').value
      root.base_uri = node.hash('baseUri').or_default('').value.gsub('{version}', root.version || '')
      root.media_type = node.hash('mediaType').value
      root.secured_by = node.hash('securedBy').or_default([]).array_values { |n| n.value }
      root.documentation = node.hash('documentation').array_values { |n| parse_documenation(n) }
      root.schemas = node.hash('schemas').arrayhash_values { |n| n.value }
      root.security_schemes = node.hash('securitySchemes').arrayhash_values { |n| parse_security_scheme(n) }
      root.resource_types = node.hash('resourceTypes').mark_all(:used).arrayhash_values { |n| n }
      root.traits = node.hash('traits').mark_all(:used).arrayhash_values { |n| n }

      implicit_protocols = (root.base_uri.scan(/^(http|https):\/\//).first || []).map { |p| p.upcase }
      explicit_protocols = node.hash('protocols').array_values { |n| n.value }
      root.protocols = explicit_protocols.empty? ? implicit_protocols : explicit_protocols

      implicit_base_uri_parameters = extract_uri_parameters(root.base_uri, true)
      explicit_base_uri_parameters = node.hash('baseUriParameters').hash_values { |n| parse_named_parameter(n, true) }
      root.base_uri_parameters = implicit_base_uri_parameters.merge(explicit_base_uri_parameters)

      root.resources = traverse_resources(node, nil) do |n,parent|
        parent_absolute_uri = parent != nil ? parent.absolute_uri : root.base_uri || ''
        parent_relative_uri = parent != nil ? parent.relative_uri : ''
        parent_uri_parameters = parent != nil ? parent.uri_parameters.clone : {}
        parse_resource(n, root, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, false)
      end

      root
    end

    def self.parse_resource(node, root, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, as_partial)
      node = node.or_default({})
      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.display_name = node.hash('displayName').value
      resource.description = node.hash('description').value
      resource.type = parse_type(node.hash('type'))
      resource.is = parse_is(node.hash('is'))
      resource.secured_by = (root.secured_by + node.hash('securedBy').or_default([]).array_values { |n| n.value }).uniq
      resource.methods = Hash[find_method_nodes(node).map { |n| [n.key, parse_method(n, root, resource, as_partial)] }]

      root_base_uri_parameters = root.base_uri_parameters
      own_base_uri_parameters = node.hash('baseUriParameters').hash_values { |n| parse_named_parameter(n, true) }
      resource.base_uri_parameters = root_base_uri_parameters.merge(own_base_uri_parameters)

      implicit_uri_parameters = extract_uri_parameters(node.key, true)
      explicit_uri_parameters = node.hash('uriParameters').hash_values { |n| parse_named_parameter(n, true) }
      raise 'Can only explicitly specify URI parameters from the current relative URI' unless as_partial or (explicit_uri_parameters.keys - implicit_uri_parameters.keys).empty?
      resource.uri_parameters = parent_uri_parameters.merge(implicit_uri_parameters).merge(explicit_uri_parameters)

      unless as_partial
        resource = mixin_resource_types(node, root, resource)
        resource.display_name = resource.relative_uri unless resource.display_name
      end

      resource
    end

    def self.parse_method(node, root, resource, as_partial)
      node = node.or_default({})
      method = Model::Method.new(node.key.upcase)
      method.description = node.hash('description').value
      method.query_parameters = node.hash('queryParameters').hash_values { |n| parse_named_parameter(n, false) }
      method.bodies = node.hash('body').hash_values { |n| parse_body(n, root) }
      method.responses = node.hash('responses').hash_values { |n| parse_response(n, root) }
      method.headers = node.hash('headers').hash_values { |n| parse_named_parameter(n, false) }
      method.secured_by = (resource.secured_by + node.hash('securedBy').or_default([]).array_values { |n| n.value }).uniq if resource
      method.is = parse_is(node.hash('is'))

      root_protocols = as_partial ? [] : root.protocols
      explicit_protocols = node.hash('protocols').array_values { |n| n.value }
      method.protocols = explicit_protocols.empty? ? root_protocols : explicit_protocols

      unless as_partial
        method = mixin_traits(node, root, method, resource)
      end

      method
    end

    def self.parse_response(node, root)
      node = node.or_default({})
      response = Model::Response.new(node.key)
      response.display_name = node.hash('displayName').value
      response.description = node.hash('description').value
      response.bodies = node.hash('body').hash_values { |n| parse_body(n, root) }
      response.headers = node.hash('headers').hash_values { |n| parse_named_parameter(n, false) }
      response
    end

    def self.parse_named_parameter(node, required_per_default)
      if node.value.is_a? Array
        node.mark_all(:unsupported)
        # TODO: Not yet supported named parameters with multiple types
        return Model::NamedParameter.new(node.key)
      end

      node = node.or_default({})
      named_parameter = Model::NamedParameter.new(node.key)
      named_parameter.type = node.hash('type').or_default('string').value
      named_parameter.display_name = node.hash('displayName').or_default(named_parameter.name).value
      named_parameter.description = node.hash('description').value
      named_parameter.required = node.hash('required').or_default(required_per_default).value
      named_parameter.default = node.hash('default').value
      named_parameter.example = node.hash('example').value
      named_parameter.min_length = node.hash('minLength').value
      named_parameter.max_length = node.hash('maxLength').value
      named_parameter.minimum = node.hash('minimum').value
      named_parameter.maximum = node.hash('maximum').value
      named_parameter.repeat = node.hash('repeat').value
      named_parameter.enum = node.hash('enum').or_default([]).array_values { |n| n.value }
      named_parameter.pattern = node.hash('pattern').value
      named_parameter
    end

    def self.parse_body(node, root)
      node = node.or_default({})
      body = Model::Body.new(node.key)
      body.example = node.hash('example').value
      body.schema = node.hash('schema').value
      body.schema = root.schemas[body.schema] if root.schemas.has_key? body.schema
      body.form_parameters = node.hash('formParameters').hash_values { |n| parse_named_parameter(n, false) }
      # TODO: Form parameters are only allowed for media type application/x-www-form-urlencoded or multipart/form-data
      body
    end

    def self.parse_security_scheme(node)
      node = node.or_default({})
      security_scheme = Model::SecurityScheme.new(node.key)
      security_scheme.type = node.hash('type').value
      security_scheme.description = node.hash('description').value
      security_scheme.described_by = parse_method(node.hash('describedBy'), nil, nil, true)
      security_scheme.settings = node.hash('settings').mark_all(:used).value
      security_scheme
    end

    def self.parse_documenation(node)
      node = node.or_default({})
      documentation = Model::Documentation.new
      documentation.title = node.hash('title').value
      documentation.content = node.hash('content').value
      documentation
    end

    def self.parse_type(node)
      node = node.or_default({}).mark_all(:used)
      result = {}
      if node.value.is_a? String
        result = { node.value => nil }
      elsif node.value.is_a? Hash
        result = node.value
      else
        raise "Invalid syntax for 'type' property at #{node.path}"
      end
      result
    end

    def self.parse_is(node)
      node = node.or_default({}).mark_all(:used)
      result = {}
      node.value.each { |n|
        if n.is_a? String
          result = result.merge({ n => nil })
        elsif n.is_a? Hash
          result = result.merge(n)
        else
          raise "Invalid syntax for 'is' property at #{node.path}"
        end
      }
      result
    end

    def self.mixin_resource_types(node, root, resource)
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
          raise "Referencing unknown resource type #{name} at #{node.path}"
        end
      end

      Model::Resource.merge(result, resource)
    end

    def self.mixin_traits(node, root, method, resource)
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
          raise "Referencing unknown trait #{name} at #{node.path}"
        end
      end

      Model::Method.merge(result, method)
    end

    def self.resolve_parametrization(node, params)
      require 'active_support/core_ext/string/inflections'

      def self.alter_string(str, params, node)
        str.gsub(/<<([a-zA-Z]+)(\s*\|\s*!([a-zA-Z_\-]+))?>>/) do |a,b|
          case $3
            when nil
              params[$1].to_s
            when 'singularize'
              params[$1].to_s.singularize
            when 'pluralize'
              params[$1].to_s.pluralize
            else
              raise "Using unknown parametrization function #{$3} at #{node.path}"
          end
        end
      end

      def self.traverse(raw, params, node)
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

    def self.find_resource_nodes(node)
      def self.is_resource(key)
        key =~ /^\//
      end
      (node.value || {}).select { |k,_| is_resource(k) }.map { |k,_| node.hash(k) }
    end

    def self.find_method_nodes(node)
      def self.is_method(key)
        %w(get post put delete head patch options trace connect).include? key
      end
      (node.value || {}).select { |k,_| is_method(k) }.map { |k,_| node.hash(k) }
    end

    def self.extract_uri_parameters(uri, required_per_default)
      names = uri.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first }
      Hash[names.map { |name| [name, Model::NamedParameter.new(name, 'string', name, nil, required_per_default)] }]
    end

    def self.traverse_resources(node, parent_resource, &code)
      find_resource_nodes(node).map { |n|
        resource = code.call(n, parent_resource)
        [resource] + traverse_resources(n, resource, &code)
      }.flatten
    end
  end
end
