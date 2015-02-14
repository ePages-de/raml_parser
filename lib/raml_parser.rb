require 'raml_parser/yaml_helper'
require 'raml_parser/model'

module RamlParser
  class Parser
    def initialize(options = {})
      defaults = {
        :semantic_error => :error,
        :key_unknown => :error,
        :not_yet_supported => :warning
      }
      @options = defaults.merge(options)
    end

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
            n.each { |n2| n2.each { |n3| root.traits[n3.key] = parse_method(root, n3, nil, true) } }
          when 'resourceTypes'
            key_not_yet_supported(node, n.key)
          when 'documentation'
            key_not_yet_supported(node, n.key)
          when 'securitySchemes'
            key_not_yet_supported(node, n.key)
          when 'securedBy'
            key_not_yet_supported(node, n.key)
          when 'mediaType'
            key_not_yet_supported(node, n.key)
          when 'schemas'
            key_not_yet_supported(node, n.key)
          when 'baseUriParameters'
            key_not_yet_supported(node, n.key)
          when 'uriParameters'
            key_not_yet_supported(node, n.key)
          when /^\//
            # gets handled separately
          else
            key_unknown(node, n.key)
        end
      end

      resource_nodes = find_resource_nodes(node)
      resource_nodes.each { |n| n.data = parse_resource(root, n) }
      root.resources = resource_nodes.map { |n| n.data }

      root
    end

    def parse_resource(root, node)
      parent_absolute_uri = if node.parent.data != nil then node.parent.data.absolute_uri else root.base_uri || '' end
      parent_relative_uri = if node.parent.data != nil then node.parent.data.relative_uri else '' end
      parent_uri_parameters = if node.parent.data != nil then node.parent.data.uri_parameters.clone else {} end

      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.uri_parameters = parent_uri_parameters

      new_uri_parameters = node.key.scan(/\{([a-zA-Z\_\-]+)\}/).map { |m| m.first }
      new_uri_parameters.each do |name|
        resource.uri_parameters[name] = Model::NamedParameter.new(name, 'string', name)
      end

      node.each { |n|
        case n.key
          when 'displayName'
            resource.display_name = n.value
          when 'description'
            resource.description = n.value
          when 'uriParameters'
            n.each do |n2|
              if new_uri_parameters.include? n2.key
                resource.uri_parameters[n2.key] = parse_named_parameter(root, n2)
              else
                semantic_error(n, "Found URI parameter definition for non existent key '#{n2.key}'")
              end
            end
          when 'is'
            resource.is += n.value
          when 'type'
            key_not_yet_supported(node, n.key)
          when 'securedBy'
            key_not_yet_supported(node, n.key)
          when /^(get|post|put|delete|head|patch|options|trace|connect)$/
            resource.methods[n.key] = parse_method(root, n, resource, false)
          when /^\//
            # gets handled separately
          else
            key_unknown(node, n.key)
        end
      }

      resource.display_name = resource.relative_uri unless resource.display_name

      resource
    end

    def parse_method(root, node, resource, as_trait)
      method = Model::Method.new(if not as_trait then node.key.upcase else nil end)

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
            method.is += n.value
          when 'securedBy'
            key_not_yet_supported(node, n.key)
          when 'headers'
            n.each { |n2| method.headers[n2.key] = parse_named_parameter(root, n2) }
          else
            key_unknown(node, n.key)
        end
      }

      method = mixin_traits(method, resource, root.traits, node) unless as_trait
      method.display_name = method.method unless method.display_name

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
            key_unknown(node, n.key)
        end
      end

      response
    end

    def parse_named_parameter(root, node)
      named_parameter = Model::NamedParameter.new(node.key)

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
            named_parameter.key_unknown(node, n.key)
        end
      }

      named_parameter.type = 'string' unless named_parameter.type != nil
      named_parameter.display_name = named_parameter.name unless named_parameter.display_name != nil
      named_parameter.required = false unless named_parameter.required != nil

      named_parameter
    end

    def parse_body(root, node)
      body = Model::Body.new(node.key)

      node.each do |n|
        case n.key
          when 'example'
            body.example = n.value
          when 'schema'
            body.schema = n.value
          when 'formParameters'
            key_not_yet_supported(node, n.key)
          else
            key_unknown(node, n.key)
        end
      end

      body
    end

    def mixin_traits(method, resource, traits, node)
      Model::Method.merge((resource.is + method.is).inject(Model::Method.new(nil)) { |m,t|
        if t.is_a? String
          if traits.has_key? t
            Model::Method.merge(m, traits[t])
          else
            semantic_error(node, "Importing unknown trait #{t}")
            m
          end
        else
          not_yet_supported(node, 'Parametrized traits')
          m
        end
      }, method)
    end

    def find_resource_nodes(node)
      nodes = []

      node.each do |n|
        if n.key =~ /^\//
          unless n.key.scan(/\{([a-zA-Z\_]+)\}/).map { |m| m.first }.include? 'mediaTypeExtension'
            nodes << n
            nodes += find_resource_nodes(n)
          else
            not_yet_supported(node, "URI parameter named mediaTypeExtension")
          end
        end
      end

      nodes.flatten
    end

    def key_not_yet_supported(node, key)
      message = "Not yet supported key '#{key}' at node '#{node.path}"
      case @options[:not_yet_supported]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end

    def key_unknown(node, key)
      message = "Unknown key '#{key}' at node '#{node.path}"
      case @options[:key_unknown]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end

    def not_yet_supported(node, msg)
      message = "Not yet supported '#{msg}' at node '#{node.path}"
      case @options[:not_yet_supported]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end

    def semantic_error(node, err)
      message = "Error '#{err}' at node '#{node.path}"
      case @options[:semantic_error]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end
  end
end
