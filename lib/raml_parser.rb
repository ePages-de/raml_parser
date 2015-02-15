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
      @root = parse_file(@path)
    end

    private

    def parse_file(path)
      tree = YamlTree.new(YamlHelper.read_yaml(path))
      parse_root(tree.root)
    end

    def parse_root(node)
      root = Model::Root.new

      node.each do |n|
        case n.key
          when 'title'
            root.title = n.value
          when 'baseUri'
            root.base_uri = n.value
          when 'version'
            root.version = n.value
          when 'traits'
            n.each { |n2| n2.each { |n3| root.traits[n3.key] = n3 } }
          when 'resourceTypes'
            n.each { |n2| n2.each { |n3| root.resource_types[n3.key] = n3 } }
          when 'documentation'
            not_yet_supported(node, n.key)
          when 'securitySchemes'
            not_yet_supported(node, n.key)
          when 'securedBy'
            not_yet_supported(node, n.key)
          when 'mediaType'
            not_yet_supported(node, n.key)
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

      resource_nodes = find_resource_nodes(node)
      resource_nodes.each { |n| n.data = parse_resource(root, n, false) }
      resource_nodes.each { |n|
        if n.data.uri_parameters.keys.include? 'mediaTypeExtension'
          not_yet_supported(node, "URI parameter named mediaTypeExtension")
        end

        if (n.data.uri_parameters.keys - n.data.relative_uri.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first }).length > 0
          error(:semantic_error, n, "Found URI parameter definition for non existent key")
        end
      }
      root.resources = resource_nodes.map { |n| n.data }

      root
    end

    def parse_resource(root, node, as_resource_type)
      parent_absolute_uri = if node.parent.data != nil then node.parent.data.absolute_uri else root.base_uri || '' end
      parent_relative_uri = if node.parent.data != nil then node.parent.data.relative_uri else '' end
      parent_uri_parameters = if node.parent.data != nil then node.parent.data.uri_parameters.clone else {} end

      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.uri_parameters = parent_uri_parameters

      node.each { |n|
        case n.key
          when 'displayName'
            resource.display_name = n.value
          when 'description'
            resource.description = n.value
          when 'uriParameters'
            n.each { |n2| resource.uri_parameters[n2.key] = parse_named_parameter(root, n2) }
          when 'is'
            n.value.each { |n2|
              if n2.is_a? String
                resource.is = resource.is.merge({ n2 => nil })
              elsif n2.is_a? Hash
                resource.is = resource.is.merge(n2)
              else
                error(:semantic_error, node, 'Invalid is format')
              end
            }
          when 'type'
            if n.value.is_a? String
              resource.type = { n.value => nil }
            elsif n.value.is_a? Hash
              resource.type = n.value
            else
              error(:semantic_error, node, 'Invalid type format')
            end
          when 'securedBy'
            not_yet_supported(node, n.key)
          when 'usage'
            unless as_resource_type
              error(:key_unknown, node, n.key)
            else
              not_yet_supported(node, n.key)
            end
          when /^(get|post|put|delete|head|patch|options|trace|connect)\??$/
            if not n.key.end_with? '?' or as_resource_type
              resource.methods[n.key] = parse_method(root, n, resource, as_resource_type)
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
        resource = mixin_resource_types(resource, node, root)
        resource.display_name = resource.relative_uri unless resource.display_name
      end
      (node.key.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first } - resource.uri_parameters.keys).each do |name|
        resource.uri_parameters[name] = Model::NamedParameter.new(name, 'string', name)
      end

      resource
    end

    def parse_method(root, node, resource, as_trait)
      method = Model::Method.new(node.key.upcase)

      node.each { |n|
        case n.key
          when 'displayName'
            method.display_name = n.value
          when 'description'
            method.description = n.value
          when 'queryParameters'
            n.each { |n2| method.query_parameters[n2.key] = parse_named_parameter(root, n2) }
          when 'body'
            n.each { |n2| method.bodies[n2.key] = parse_body(root, n2) }
          when 'responses'
            n.each { |n2| method.responses[n2.key] = parse_response(root, n2) }
          when 'is'
            n.value.each { |n2|
              if n2.is_a? String
                method.is = method.is.merge({ n2 => nil })
              elsif n2.is_a? Hash
                method.is = method.is.merge(n2)
              else
                error(:key_unknown, node, 'Invalid is format')
              end
            }
          when 'securedBy'
            not_yet_supported(node, n.key)
          when 'headers'
            n.each { |n2| method.headers[n2.key] = parse_named_parameter(root, n2) }
          else
            error(:key_unknown, node, n.key)
        end
      }

      unless as_trait
        method = mixin_traits(method, resource, node, root)
        method.display_name = method.method unless method.display_name
      end

      method
    end

    def parse_response(root, node)
      response = Model::Response.new(node.key)

      node.each do |n|
        case n.key
          when 'displayName'
            response.display_name = n.value
          when 'description'
            response.description = n.value
          when 'body'
            n.each { |n2| response.bodies[n2.key] = parse_body(root, n2) }
          when 'headers'
            n.each { |n2| response.headers[n2.key] = parse_named_parameter(root, n2) }
          else
            error(:key_unknown, node, n.key)
        end
      end

      response
    end

    def parse_named_parameter(root, node)
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

    def parse_body(root, node)
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
              n.each { |n2| body.form_parameters[n2.key] = parse_named_parameter(root, n2) }
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

    def mixin_resource_types(resource, node, root)
      def find_resource_type(name, root, params)
        if root.resource_types.has_key? name
          unresolved = root.resource_types[name]
          resolved = YamlNode.new(unresolved.parent, unresolved.key, resolve_parameters(unresolved.value, params, unresolved))
          parse_resource(root, resolved, true)
        else
          nil
        end
      end

      result = Model::Resource.new(nil, nil)
      resource.type.each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s
        })
        resource_type = find_resource_type(name, root, params)
        if resource_type != nil
          result = Model::Resource.merge(result, resource_type)
        else
          error(:key_unknown, node, "Importing unknown resource type #{name}")
        end
      end

      Model::Resource.merge(result, resource)
    end

    def mixin_traits(method, resource, node, root)
      def find_trait(name, root, params)
        if root.traits.has_key? name
          unresolved = root.traits[name]
          resolved = YamlNode.new(unresolved.parent, unresolved.key, resolve_parameters(unresolved.value, params, unresolved))
          parse_method(root, resolved, nil, true)
        else
          nil
        end
      end

      result = Model::Method.new(nil)
      (resource.is.merge(method.is)).each do |name,value|
        params = (value || {}).merge({
            'resourcePath' => resource.relative_uri,
            'resourcePathName' => resource.relative_uri.match(/[^\/]*$/).to_s,
            'methodName' => method.method.downcase
        })
        trait = find_trait(name, root, params)
        if trait != nil
          result = Model::Method.merge(result, trait)
        else
          error(:key_unknown, node, "Importing unknown trait #{name}")
        end
      end

      Model::Method.merge(result, method)
    end

    def resolve_parameters(raw, params, original_node)
      def alter_string(str, params, original_node)
        str.gsub(/<<([a-zA-Z]+)(\s*\|\s*!([a-zA-Z_\-]+))?>>/) do |a,b|
          case $3
            when nil
              params[$1]
            when 'singularize'
              not_yet_supported(original_node, 'Singularization of parameters')
            when 'pluralize'
              not_yet_supported(original_node, 'Pluralization of parameters')
            else
              error(:key_unknown, original_node, "Unknown parameter pipe function '#{$3}'")
          end
        end
      end

      if raw.is_a? Hash
        Hash[raw.map { |k,v| [resolve_parameters(k, params, original_node), resolve_parameters(v, params, original_node)] }]
      elsif raw.is_a? Array
        raw.map { |i| resolve_parameters(i, params, original_node) }
      elsif raw.is_a? String
        alter_string(raw, params, original_node)
      else
        raw
      end
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
