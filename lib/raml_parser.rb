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
            n.each do |n2|
              n2.each do |n3|
                trait = parse_trait(n3)
                root.traits[trait.name] = trait
              end
            end
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
            # gets handled in the next step
          else
            key_unknown(node, n.key)
        end
      end

      root.resources += node.map { |n|
        if n.key =~ /^\//
          parse_resource(n, root.base_uri || '', '', {}, root.traits)
        else
          []
        end
      }.flatten

      root
    end

    def parse_resource(node, parent_absolute_uri, parent_relative_uri, parent_uri_parameters, traits)
      resource = Model::Resource.new(parent_absolute_uri + node.key, parent_relative_uri + node.key)
      resource.uri_parameters = parent_uri_parameters

      relative_uri_uri_parameters = node.key.scan(/\{([a-zA-Z\_]+)\}/).map { |m| m.first }
      relative_uri_uri_parameters.each do |name|
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
              if relative_uri_uri_parameters.include? n2.key
                resource.uri_parameters[n2.key] = parse_named_parameter(n2)
              else
                semantic_error(n, "Found URI parameter definition for non existent key '#{n2.key}'")
              end
            end
          when 'is'
            key_not_yet_supported(node, n.key)
          when 'type'
            key_not_yet_supported(node, n.key)
          when 'securedBy'
            key_not_yet_supported(node, n.key)
          when /^(get|post|put|delete|head|patch|options|trace|connect)$/
            resource.methods[n.key] = parse_method(n, traits)
          when /^\//
            # gets handled in the next step
          else
            key_unknown(node, n.key)
        end
      }

      child_resources = node.map do |n|
        if n.key =~ /^\//
          parse_resource(n, parent_absolute_uri + n.key, parent_relative_uri + n.key, resource.uri_parameters.clone, traits)
        else
          []
        end
      end

      [resource] + child_resources
    end

    def parse_named_parameter(node)
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

      named_parameter.type = named_parameter.type || 'string'
      named_parameter.display_name = named_parameter.display_name || named_parameter.name
      named_parameter.required = named_parameter.required != nil ? named_parameter.required : false

      named_parameter
    end

    def parse_method(node, traits)
      method = Model::Method.new(node.key.upcase)

      node.each { |n|
        case n.key
          when 'displayName'
            method.display_name = n.value
          when 'description'
            method.description = n.value
          when 'queryParameters'
            n.each { |n2| method.query_parameters[n2.key] = parse_named_parameter(n2) }
          when 'body'
            key_not_yet_supported(node, n.key)
          when 'responses'
            key_not_yet_supported(node, n.key)
          when 'is'
            n.each { |n2| mixin_trait(method, n2, traits) }
          when 'securedBy'
            key_not_yet_supported(node, n.key)
          when 'headers'
            key_not_yet_supported(node, n.key)
          else
            key_unknown(node, n.key)
        end
      }

      method
    end

    def parse_trait(node)
      trait = Model::Trait.new(node.key)

      node.each do |n|
        case n.key
          when 'displayName'
            trait.display_name = n.value
          when 'description'
            trait.description = n.value
          when 'queryParameters'
            n.each do |n2|
              trait.query_parameters[n2.key] = parse_named_parameter(n2)
            end
          when 'headers'
            key_not_yet_supported(node, n.key)
          when 'responses'
            key_not_yet_supported(node, n.key)
          else
            key_unknown(node, n.key)
        end
      end

      trait
    end

    def mixin_trait(method, node, traits)
      if node.value.is_a? String
        if traits.has_key? node.value
          trait = traits[node.value]
          if trait.display_name != nil
            method.display_name = trait.display_name
          end

          if trait.description != nil
            method.description = trait.description
          end

          if trait.query_parameters != nil
            trait.query_parameters.each do |name,param|
              method.query_parameters[name] = param
            end
          end
        else
          semantic_error(node, "Importing unknown trait #{n2.value}")
        end
      else
        not_yet_supported(node, 'Parametrized traits')
      end
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
