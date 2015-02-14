module RamlParser
  module Model
    class Root
      attr_accessor :title, :base_uri, :version, :traits, :resource_types, :resources

      def initialize(title = nil, base_uri = nil, version = nil, traits = {}, resource_types = {}, resources = [])
        @title = title
        @base_uri = base_uri
        @version = version
        @traits = traits
        @resource_types = resource_types
        @resources = resources
      end
    end

    class Resource
      attr_accessor :absolute_uri, :relative_uri, :display_name, :description, :uri_parameters, :methods, :is

      def initialize(absolute_uri, relative_uri, display_name = nil, description = nil, uri_parameters = {}, methods = {}, is = [])
        @absolute_uri = absolute_uri
        @relative_uri = relative_uri
        @display_name = display_name
        @description = description
        @uri_parameters = uri_parameters
        @methods = methods
        @is = is
      end
    end

    class Method
      attr_accessor :method, :display_name, :description, :query_parameters, :responses, :bodies, :headers, :is

      def initialize(method, display_name = nil, description = nil, query_parameters = {}, responses = {}, bodies = {}, headers = {}, is = [])
        @method = method
        @display_name = display_name
        @description = description
        @query_parameters = query_parameters
        @responses = responses
        @bodies = bodies
        @headers = headers
        @is = is
      end

      def self.merge(a, b)
        method = Method.new(b.method)

        method.display_name = if b.display_name then b.display_name else a.display_name end
        method.description = if b.description then b.description else a.description end
        method.query_parameters = a.query_parameters.merge(b.query_parameters)
        method.responses = a.responses.merge(b.responses)
        method.bodies = a.bodies.merge(b.bodies)
        method.headers = a.headers.merge(b.headers)
        method.is = (a.is + b.is).uniq

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
      attr_accessor :media_type, :example, :schema

      def initialize(media_type, example = nil, schema = nil)
        @media_type = media_type
        @example = example
        @schema = schema
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
  end
end
