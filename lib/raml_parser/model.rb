module RamlParser
  module Model
    class Root
      attr_accessor :title, :base_uri, :version, :media_type, :schemas, :security_schemes, :base_uri_parameters, :resource_types, :traits, :protocols, :secured_by, :documentation, :resources

      def initialize(title = nil, base_uri = nil, version = nil, media_type = nil, schemas = {}, security_schemes = {}, base_uri_parameters = {}, resource_types = {}, traits = {}, protocols = [], secured_by = [], documentation = [], resources = [])
        @title = title
        @base_uri = base_uri
        @version = version
        @media_type = media_type
        @schemas = schemas
        @security_schemes = security_schemes
        @base_uri_parameters = base_uri_parameters
        @resource_types = resource_types
        @traits = traits
        @protocols = protocols
        @secured_by = secured_by
        @documentation = documentation
        @resources = resources
      end
    end

    class Resource
      attr_accessor :absolute_uri, :relative_uri, :display_name, :description, :base_uri_parameters, :uri_parameters, :methods, :type, :is, :secured_by

      def initialize(absolute_uri, relative_uri, display_name = nil, description = nil, base_uri_parameters = {}, uri_parameters = {}, methods = {}, type = {}, is = {}, secured_by = [])
        @absolute_uri = absolute_uri
        @relative_uri = relative_uri
        @display_name = display_name
        @description = description
        @base_uri_parameters = base_uri_parameters
        @uri_parameters = uri_parameters
        @methods = methods
        @type = type
        @is = is
        @secured_by = secured_by
      end

      def self.merge(a, b)
        resource = Resource.new(b.absolute_uri, b.relative_uri)

        resource.display_name = if b.display_name then b.display_name else a.display_name end
        resource.description = if b.description then b.description else a.description end
        resource.base_uri_parameters = a.base_uri_parameters.merge(b.base_uri_parameters)
        resource.uri_parameters = a.uri_parameters.merge(b.uri_parameters)
        resource.methods = a.methods.merge(b.methods)
        resource.methods.keys.each do |meth|
          next if a.methods[meth].nil?
          resource.methods[meth] = Method.merge(a.methods[meth], resource.methods[meth])
        end
        resource.type = a.type.merge(b.type)
        resource.is = a.is.merge(b.is)
        resource.secured_by = (a.secured_by + b.secured_by).uniq

        resource
      end
    end

    class Method
      attr_accessor :method, :description, :query_parameters, :responses, :bodies, :headers, :is, :protocols, :secured_by

      def initialize(method, description = nil, query_parameters = {}, responses = {}, bodies = {}, headers = {}, is = {}, protocols = [], secured_by = [])
        @method = method
        @description = description
        @query_parameters = query_parameters
        @responses = responses
        @bodies = bodies
        @headers = headers
        @is = is
        @protocols = protocols
        @secured_by = secured_by
      end

      def self.merge(a, b)
        method = Method.new(b.method)

        method.description = if b.description then b.description else a.description end
        method.query_parameters = a.query_parameters.merge(b.query_parameters)
        method.responses = a.responses.merge(b.responses)
        method.bodies = a.bodies.merge(b.bodies)
        method.headers = a.headers.merge(b.headers)
        method.is = a.is.merge(b.is)
        method.protocols = (a.protocols + b.protocols).uniq
        method.secured_by = (a.secured_by + b.secured_by).uniq

        method
      end
    end

    class Response
      attr_accessor :status_code, :display_name, :description, :bodies, :headers

      def initialize(status_code, display_name = nil, description = nil, bodies = {}, headers = {})
        @status_code = status_code
        @display_name = display_name
        @description = description
        @bodies = bodies
        @headers = headers
      end
    end

    class Body
      attr_accessor :media_type, :example, :schema, :form_parameters

      def initialize(media_type, example = nil, schema = nil, form_parameters = {})
        @media_type = media_type
        @example = example
        @schema = schema
        @form_parameters = form_parameters
      end
    end

    class NamedParameter
      attr_accessor :name, :type, :display_name, :description, :required, :default, :example, :min_length, :max_length, :minimum, :maximum, :repeat, :enum, :pattern

      def initialize(name, type = nil, display_name = nil, description = nil, required = false, default = nil, example = nil, min_length = nil, max_length = nil, minimum = nil, maximum = nil, repeat = nil, enum = nil, pattern = nil)
        @name = name
        @type = type
        @display_name = display_name
        @description = description
        @required = required
        @default = default
        @example = example
        @min_length = min_length
        @max_length = max_length
        @minimum = minimum
        @maximum = maximum
        @repeat = repeat
        @enum = enum
        @pattern = pattern
      end
    end

    class Documentation
      attr_accessor :title, :content

      def initialize(title = nil, content = nil)
        @title = title
        @content = content
      end
    end

    class SecurityScheme
      attr_accessor :name, :type, :description, :described_by, :settings

      def initialize(name, type = nil, description = nil, described_by = nil, settings = {})
        @name = name
        @type = type
        @description = description
        @described_by = described_by
        @settings = settings
      end
    end
  end
end
