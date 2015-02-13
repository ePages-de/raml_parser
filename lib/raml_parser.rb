require 'raml_parser/yaml_helper'
require 'raml_parser/model'

module RamlParser
  class Parser
    def initialize(options = {})
      defaults = {
        :semantic_error => :error,
        :unknown_key => :error,
        :not_yet_supported => :warning
      }
      @options = defaults.merge(options)
    end

    def parse_file(path)
      tree = YamlTree.new(YamlHelper.read_yaml(path))
      parse_root(tree.root)
    end

    def parse_root(node)
      title = nil
      base_uri = nil
      version = nil
      traits = {}
      resources = []

      node.each do |n|
        case n.key
          when 'title'
            title = n.value
          when 'baseUri'
            base_uri = n.value
          when 'version'
            version = n.value
          when 'traits'
            n.each do |n2|
              n2.each do |n3|
                trait = parse_trait(n3)
                traits[trait.name] = trait
              end
            end
          when 'resourceTypes'
            not_yet_supported(node, n.key)
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
            # gets handled in the next step
          else
            unknown_key(node, n.key)
        end
      end

      resources += node.map do |n|
        if n.key =~ /^\//
          parse_resource(n, base_uri || '', '', {})
        else
          []
        end
      end

      Model::Root.new(
          title,
          base_uri,
          version,
          traits,
          resources.flatten
      )
    end

    def parse_resource(node, parent_absolute_uri, parent_relative_uri, parent_uri_parameters)
      display_name = nil
      description = nil
      uri_parameters = parent_uri_parameters
      methods = {}

      relative_uri_uri_parameters = node.key.scan(/\{([a-zA-Z\_]+)\}/).map { |m| m.first }
      relative_uri_uri_parameters.each do |name|
        uri_parameters[name] = Model::NamedParameter.new(name, 'string', name)
      end

      node.each { |n|
        case n.key
          when 'displayName'
            display_name = n.value
          when 'description'
            description = n.value
          when 'uriParameters'
            n.each do |n2|
              if relative_uri_uri_parameters.include? n2.key
                uri_parameters[n2.key] = parse_named_parameter(n2)
              else
                semantic_error(n, "Found URI parameter definition for non existent key '#{n2.key}'")
              end
            end
          when 'is'
            not_yet_supported(node, n.key)
          when 'type'
            not_yet_supported(node, n.key)
          when 'securedBy'
            not_yet_supported(node, n.key)
          when /^(get|post|put|delete|head|patch|options|trace|connect)$/
            methods[n.key] = parse_method(n)
          when /^\//
            # gets handled in the next step
          else
            unknown_key(node, n.key)
        end
      }

      child_resources = node.map do |n|
        if n.key =~ /^\//
          parse_resource(n, parent_absolute_uri + n.key, parent_relative_uri + n.key, uri_parameters.clone)
        else
          []
        end
      end

      resource = Model::Resource.new(
          parent_absolute_uri + node.key,
          parent_relative_uri + node.key,
          display_name || parent_relative_uri + node.key,
          description,
          uri_parameters,
          methods
      )

      [resource] + child_resources
    end

    def parse_named_parameter(node)
      name = node.key
      display_name = nil
      description = nil
      type = nil
      required = nil
      default = nil
      example = nil
      min_length = nil
      max_length = nil
      minimum = nil
      maximum = nil
      repeat = nil
      enum = nil
      pattern = nil

      node.each { |n|
        case n.key
          when 'type'
            type = n.value
          when 'displayName'
            display_name = n.value
          when 'description'
            description = n.value
          when 'required'
            required = n.value
          when 'default'
            default = n.value
          when 'example'
            example = n.value
          when 'minLength'
            min_length = n.value
          when 'maxLength'
            max_length = n.value
          when 'minimum'
            minimum = n.value
          when 'maximum'
            maximum = n.value
          when 'repeat'
            repeat = n.value
          when 'enum'
            enum = n.value
          when 'pattern'
            pattern = n.value
          else
            unknown_key(node, n.key)
        end
      }

      Model::NamedParameter.new(
          name,
          type || 'string',
          display_name || name,
          description,
          required != nil ? required : false,
          default,
          example,
          min_length,
          max_length,
          minimum,
          maximum,
          repeat,
          enum,
          pattern
      )
    end

    def parse_method(node)
      method = node.key.upcase
      display_name = nil
      description = nil
      query_parameters = {}

      node.each { |n|
        case n.key
          when 'displayName'
            display_name = n.value
          when 'description'
            description = n.value
          when 'queryParameters'
            n.each do |n2|
              query_parameters[n2.key] = parse_named_parameter(n2)
            end
          when 'body'
            not_yet_supported(node, n.key)
          when 'responses'
            not_yet_supported(node, n.key)
          when 'is'
            not_yet_supported(node, n.key)
          when 'securedBy'
            not_yet_supported(node, n.key)
          when 'headers'
            not_yet_supported(node, n.key)
          else
            unknown_key(node, n.key)
        end
      }

      Model::Method.new(method, display_name, description, query_parameters)
    end

    def parse_trait(node)
      name = node.key
      display_name = nil
      description = nil
      query_parameters = {}

      node.each do |n|
        case n.key
          when 'displayName'
            display_name = n.value
          when 'description'
            description = n.value
          when 'queryParameters'
            n.each do |n2|
              query_parameters[n2.key] = parse_named_parameter(n2)
            end
          when 'headers'
            not_yet_supported(node, n.key)
          when 'responses'
            not_yet_supported(node, n.key)
          else
            unknown_key(node, n.key)
        end
      end

      Model::Trait.new(name, display_name, description, query_parameters)
    end

    def not_yet_supported(node, key)
      message = "Not yet supported key '#{key}' at node '#{node.path}"
      case @options[:not_yet_supported]
        when :ignore
        when :warning
          puts message
        else
          raise message
      end
    end

    def unknown_key(node, key)
      message = "Unknown key '#{key}' at node '#{node.path}"
      case @options[:unknown_key]
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
