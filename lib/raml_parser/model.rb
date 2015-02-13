module RamlParser
  module Model
    class Root
      attr_reader :title, :base_uri, :version, :traits, :resources

      def initialize(title, base_uri, version, traits, resources)
        @title = title
        @base_uri = base_uri
        @version = version
        @traits = traits
        @resources = resources
      end
    end

    class Resource
      attr_reader :absolute_uri, :relative_uri, :display_name, :description, :uri_parameters, :methods

      def initialize(absolute_uri, relative_uri, display_name, description, uri_parameters, methods)
        @absolute_uri = absolute_uri
        @relative_uri = relative_uri
        @display_name = display_name
        @description = description
        @uri_parameters = uri_parameters
        @methods = methods
      end
    end

    class Method
      attr_reader :method, :display_name, :description, :query_parameters

      def initialize(method, display_name, description, query_parameters)
        @method = method
        @display_name = display_name
        @description = description
        @query_parameters = query_parameters
      end
    end

    class NamedParameter
      attr_reader :name, :type, :display_name, :description, :required, :default, :example, :min_length, :max_length, :minimum, :maximum, :repeat, :enum, :pattern

      def initialize(name, type, display_name, description = nil, required = false, default = nil, example = nil, min_length = nil, max_length = nil, minimum = nil, maximum = nil, repeat = nil, enum = nil, pattern = nil)
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

    class Trait
      attr_reader :name, :display_name, :description, :query_parameters

      def initialize(name, display_name, description, query_parameters)
        @name = name
        @display_name = display_name
        @description = description
        @query_parameters = query_parameters
      end
    end
  end
end
