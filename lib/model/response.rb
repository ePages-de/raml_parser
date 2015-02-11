require 'yaml_helper'

module RamlParser
  module Model
    class Response
      attr_accessor :status_code, :description

      def to_liquid
        {
          'status_code' => @status_code,
          'description' => @description
        }
      end
    end
  end
end
