require 'raml_parser/yaml_helper'
require 'raml_parser/model'

module RamlParser
  class Parser
    attr_reader :path, :root

    def initialize(path, options = {})
      @path = path
      @options = {
          :semantic_error => :error,
          :key_unknown => :error,
          :not_yet_supported => :warning
      }.merge(options)
      @traits = {}
      @resource_types = {}
      parse_file(@path)
    end

    private

    def parse_file(path)
      tree = YamlTree.new(YamlHelper.read_yaml(path))
      parse_root(tree.root)
    end

    def parse_root(node)
      @root = Model::Root.new

      node.each do |n|
        case n.key
          when 'title'
            @root.title = n.value
          when 'baseUri'
            @root.base_uri = n.value
          when 'version'
            @root.version = n.value
          when 'traits'
            n.each { |n2| n2.each { |n3| @traits[n3.key] = n3 } }
          when 'resourceTypes'
            n.each { |n2| n2.each { |n3| @resource_types[n3.key] = n3 } }
          when 'securitySchemes'
            n.each { |n2| n2.each { |n3| @root.security_schemes[n3.key] = parse_security_scheme(n3) } }
          when 'documentation'
            @root.documentation += n.map { |n2| parse_documenation(n2) }
          when 'securedBy'
            @root.secured_by = n.value
          when 'mediaType'
            @root.media_type = n.value
          when 'schemas'
            not_yet_supported(node, n.key)
          when 'baseUriParameters'
            not_yet_supported(node, n.key)
          when 'uriParameters'
            not_yet_supported(node, n.key)
          when /^\//
            # gets handled separately
          else
            error(:key_unknown, node, n.key)
        end
      end

      @root.resources = find_resource_nodes(node).map do |n|
        parent_absolute_uri = n.parent.data != nil ? n.parent.data.absolute_uri : @root.base_uri || ''
        parent_relative_uri = n.parent.data != nil ? n.parent.data.relative_uri : ''
        parent_uri_parameters = n.parent.data != nil ? n.parent.data.uri_parameters.clone : {}
        resource = parse_resource(n, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, false)
        n.data = resource

        if (resource.uri_parameters.keys - resource.relative_uri.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first }).length > 0
          error(:semantic_error, n, "Found URI parameter definition for non existent key")
        end

        resource
      end
    end

    def parse_resource(node, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, as_resource_type)
      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.uri_parameters = parent_uri_parameters unless as_resource_type
      resource.secured_by = @root.secured_by.clone unless as_resource_type

      node.each { |n|
        case n.key
          when 'displayName'
            resource.display_name = n.value
          when 'description'
            resource.description = n.value
          when 'uriParameters'
            n.each { |n2| resource.uri_parameters[n2.key] = parse_named_parameter(n2) }
          when 'type'
            resource.type = resource.type.merge(parse_type(n))
          when 'is'
            resource.is = resource.is.merge(parse_is(n))
          when 'securedBy'
            resource.secured_by = (resource.secured_by + n.value).uniq
          when 'usage'
            unless as_resource_type
              error(:key_unknown, node, n.key)
            end
          when /^(get|post|put|delete|head|patch|options|trace|connect)\??$/
            if not n.key.end_with? '?' or as_resource_type
              resource.methods[n.key] = parse_method(n, resource, as_resource_type)
            else
              error(:key_unknown, node, n.key)
            end
          when /^\//
            # gets handled separately
          else
            error(:key_unknown, node, n.key)
        end
      }

      unless as_resource_type
        resource = mixin_resource_types(resource, node)
        resource.display_name = resource.relative_uri unless resource.display_name
        (node.key.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first } - resource.uri_parameters.keys).each do |name|
          resource.uri_parameters[name] = Model::NamedParameter.new(name, 'string', name)
        end
      end

      resource
    end

    def parse_method(node, resource, as_trait)
      method = Model::Method.new(node.key.upcase)
      method.secured_by = resource.secured_by.clone unless as_trait

      node.each { |n|
        case n.key
          when 'displayName'
            method.display_name = n.value
          when 'description'
            method.description = n.value
          when 'queryParameters'
            n.each { |n2| method.query_parameters[n2.key] = parse_named_parameter(n2) }
          when 'body'
            n.each { |n2| method.bodies[n2.key] = parse_body(n2) }
          when 'responses'
            n.each { |n2| method.responses[n2.key] = parse_response(n2) }
          when 'is'
            method.is = method.is.merge(parse_is(n))
          when 'securedBy'
            method.secured_by = (method.secured_by + n.value).uniq
          when 'headers'
            n.each { |n2| method.headers[n2.key] = parse_named_parameter(n2) }
          else
            error(:key_unknown, node, n.key)
        end
      }

      unless as_trait
        method = mixin_traits(method, resource, node)
        method.display_name = method.method unless method.display_name
      end

      method
    end

    def parse_response(node)
      response = Model::Response.new(node.key)

      node.each do |n|
        case n.key
          when 'displayName'
            response.display_name = n.value
          when 'description'
            response.description = n.value
          when 'body'
            n.each { |n2| response.bodies[n2.key] = parse_body(n2) }
          when 'headers'
            n.each { |n2| response.headers[n2.key] = parse_named_parameter(n2) }
          else
            error(:key_unknown, node, n.key)
        end
      end

      response
    end

    def parse_named_parameter(node)
      named_parameter = Model::NamedParameter.new(node.key)

      if node.value.is_a? Array
        not_yet_supported(node, 'Named parameters with multiple types')
        return named_parameter
      end

      node.each { |n|
        case n.key
          when 'type'
            named_parameter.type = n.value
          when 'displayName'
            named_parameter.display_name = n.value
          when 'description'
            named_parameter.description = n.value
          when 'required'
            named_parameter.required = n.value
          when 'default'
            named_parameter.default = n.value
          when 'example'
            named_parameter.example = n.value
          when 'minLength'
            named_parameter.min_length = n.value
          when 'maxLength'
            named_parameter.max_length = n.value
          when 'minimum'
            named_parameter.minimum = n.value
          when 'maximum'
            named_parameter.maximum = n.value
          when 'repeat'
            named_parameter.repeat = n.value
          when 'enum'
            named_parameter.enum = n.value
          when 'pattern'
            named_parameter.pattern = n.value
          else
            error(:key_unknown, node, n.key)
        end
      }

      named_parameter.type = 'string' unless named_parameter.type != nil
      named_parameter.display_name = named_parameter.name unless named_parameter.display_name != nil
      named_parameter.required = false unless named_parameter.required != nil

      named_parameter
    end

    def parse_body(node)
      body = Model::Body.new(node.key)
      needs_form_parameters = ['application/x-www-form-urlencoded', 'multipart/form-data'].include? body.media_type

      node.each do |n|
        case n.key
          when 'example'
            body.example = n.value
          when 'schema'
            body.schema = n.value
          when 'formParameters'
            if needs_form_parameters
              n.each { |n2| body.form_parameters[n2.key] = parse_named_parameter(n2) }
            else
              error(:key_unknown, node, 'Form parameters are only allowed for media type application/x-www-form-urlencoded or multipart/form-data')
            end
          else
            error(:key_unknown, node, n.key)
        end
      end

      if needs_form_parameters and body.form_parameters.empty?
        error(:key_unknown, node, 'Requests with media type application/x-www-form-urlencoded or multipart/form-data must supply form parameters')
      end

      body
    end

    def parse_security_scheme(node)
      security_scheme = Model::SecurityScheme.new(node.key)

      node.each do |n|
        case n.key
          when 'type'
            security_scheme.type = n.value
          when 'description'
            security_scheme.description = n.value
          when 'describedBy'
            security_scheme.described_by = parse_method(n, nil, true)
          when 'settings'
            security_scheme.settings = n.value
          else
            error(:key_unknown, node, n.key)
        end
      end

      security_scheme
    end

    def parse_documenation(node)
      documentation = Model::Documentation.new

      node.each do |n|
        case n.key
          when 'title'
            documentation.title = n.value
          when 'content'
            documentation.content = n.value
          else
            error(:key_unknown, node, n.key)
        end
      end

      documentation
    end

    def parse_type(node)
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

    def mixin_resource_types(resource, node)
      result = Model::Resource.new(nil, nil)
      resource.type.each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s
        })
        resource_type = @resource_types.has_key?(name) ? parse_resource(resolve_parametrization(@resource_types[name], params), '', '', {}, true) : nil
        if resource_type != nil
          result = Model::Resource.merge(result, resource_type)
        else
          error(:key_unknown, node, "Importing unknown resource type #{name}")
        end
      end

      Model::Resource.merge(result, resource)
    end

    def mixin_traits(method, resource, node)
      result = Model::Method.new(nil)
      (resource.is.merge(method.is)).each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s,
            'methodName' => method.method.downcase
        })
        trait = @traits.has_key?(name) ? parse_method(resolve_parametrization(@traits[name], params), nil, true) : nil
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

    def find_resource_nodes(node)
      nodes = []

      node.each do |n|
        if n.key =~ /^\//
          nodes << n
          nodes += find_resource_nodes(n)
        end
      end

      nodes.flatten
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
