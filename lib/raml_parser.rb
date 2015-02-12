require 'raml_parser/yaml_helper'
require 'raml_parser/model/root'
require 'raml_parser/model/resource'
require 'raml_parser/model/response'
require 'raml_parser/model/named_parameter'

module RamlParser
  class Parser
    def initialize(unknown_handling = 'error')
      @error_handling = unknown_handling
    end

    def parse_file(path)
      create_root(YamlNode.new(nil, 'root', YamlHelper.read_yaml(path)))
    end

    def create_root(node)
      root = Model::Root.new

      node.each { |n|
        case n.key
          when 'title'
            root.title = n.value
          when 'baseUri'
            root.base_uri = n.value if n.value
          when 'version'
            root.version = n.value
          when 'traits'
            root.traits = Hash[n.value.map { |t| t.first }]
          when /^\//
            # start traversing with a base resource that gets further
            # specified deeper down the RAML tree
            base_resource = Model::Resource.new
            base_resource.uri = root.base_uri + n.key
            root.resources += create_resources(n, root, base_resource)
          else
            error("Unknown key '#{n.key}'", node)
        end
      }

      root
    end

    def create_resources(node, root, base_resource)
      resources = []

      node.each { |n|
        case n.key
          when 'displayName'
            base_resource.display_name = n.value
          when 'description'
            base_resource.description = n.value
          when 'uriParameters'
            base_resource.uri_parameters = n.map { |n2| create_named_parameter(n2, root) }
          when 'queryParameters'
            base_resource.query_parameters = n.map { |n2| create_named_parameter(n2, root) }
          when 'responses'
            base_resource.responses = n.map { |n2| create_response(n2, root) }
          when 'is'
            n.value.each { |t| mixin_trait(n, root, base_resource) }
          when /^\//
            resources += create_resources(n, root, base_resource.clone_with { |r| r.uri += n.key })
          when /^(get|post|put|delete|head|patch|options|trace|connect)$/
            resources += create_resources(n, root, base_resource.clone_with { |r| r.method = n.key })
          else
            error("Unknown key '#{n.key}'", node)
        end
      }

      resources << finalize_resource(base_resource, root) if base_resource.uri and base_resource.method
      resources
    end

    def create_named_parameter(node, root)
      named_parameter = Model::NamedParameter.new
      named_parameter.name = node.key

      node.each { |n|
        case n.key
          when 'displayName'
            named_parameter.display_name = n.value
          when 'description'
            named_parameter.description = n.value
          when 'type'
            named_parameter.type = n.value
          when 'required'
            named_parameter.required = n.value
          when 'default'
            named_parameter.default = n.value
          when 'example'
            named_parameter.example = n.value
          when 'minimum'
            named_parameter.minimum = n.value
          when 'maximum'
            named_parameter.maximum = n.value
          when 'repeat'
            named_parameter.repeat = n.value
          when 'enum'
            named_parameter.enum = n.value
          else
            error("Unknown key '#{n.key}'", node)
        end
      }

      named_parameter
    end

    def create_response(node, root)
      response = Model::Response.new
      response.status_code = node.key

      node.each { |n|
        case n.key
          when 'description'
            response.description = n.value
          else
            error("Unknown key '#{n.key}'", node)
        end
      }

      response
    end

    def mixin_trait(node, root, base_resource)
      node.value.each { |t|
        if t.is_a? String and root.traits[t]
          YamlNode.new(node.root, 'traits[' + t + ']', root.traits[t]).each { |n|
            case n.key
              when 'displayName'
                base_resource.display_name = n.value
              when 'description'
                base_resource.description = n.value
              when 'uriParameters'
                base_resource.uri_parameters += n.map { |n2| create_named_parameter(n2, root) }
              when 'queryParameters'
                base_resource.query_parameters += n.map { |n2| create_named_parameter(n2, root) }
              when 'responses'
                base_resource.responses += n.map { |n2| create_response(n2, root) }
              else
                error("Mixing in #{n.key} is supported yet", n)
            end
          }
        elsif t.is_a? String and not root.traits[t]
          error("Could not find trait #{t}", node)
        else
          error("Parametrized traits are not supported yet", node)
        end
      }
    end

    def finalize_resource(resource, root)
      resource.display_name = resource.uri[root.base_uri.length..-1] unless resource.display_name
      resource.uri = resource.uri.gsub(/([^:])\/{2,}/, '\1/')

      resource.uri_parameters += resource.uri.scan(/\{([a-zA-Z]+)\}/)
        .map { |m| m.first }
        .select { |up_name| not resource.uri_parameters.find { |up| up.name == up_name } }
        .map { |up_name|
          up = Model::NamedParameter.new
          up.name = up_name
          up
        }

      resource.uri_parameters.each { |up| finalize_name_parameter(up, root, true) }
      resource.query_parameters.each { |qp| finalize_name_parameter(qp, root, false) }

      resource
    end

    def finalize_name_parameter(named_parameter, root, required_default)
      named_parameter.display_name = named_parameter.name unless named_parameter.display_name
      named_parameter.type = 'string' unless named_parameter.type
      named_parameter.repeat = false unless named_parameter.repeat
      named_parameter.required = required_default unless named_parameter.required
    end

    def error(message, node)
      case @error_handling
        when 'ignore'
        when 'warning'
          puts "Warning: '#{message}' at #{node.path}"
        else
          raise "Error: '#{message}' at #{node.path}"
      end
    end
  end
end
