require 'yaml_helper'

module RamlParser
  module Model
    class NamedParameter
      attr_accessor :name, :display_name, :description, :type, :required, :default, :example, :minimum, :maximum, :repeat, :enum

      def to_liquid
        {
          'name' => @name,
          'display_name' => @display_name,
          'description' => @description,
          'type' => @type,
          'required' => @required,
          'default' => @default,
          'example' => @example,
          'minimum' => @minimum,
          'maximum' => @maximum,
          'repeat' => @repeat,
          'enum' => @enum
        }
      end
    end
  end
end
