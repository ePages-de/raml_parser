require 'yaml_helper'

module RamlParser
  module Model
    class Resource
      attr_accessor :method, :uri, :display_name, :description, :uri_parameters, :query_parameters, :responses

      def initialize
        @uri_parameters = []
        @query_parameters = []
        @responses = []
      end

      def clone_with(&code)
        cloned = self.clone
        code.call(cloned)
        cloned
      end

      def to_liquid
        {
          'method' => @method,
          'uri' => @uri,
          'display_name' => @display_name,
          'description' => @description,
          'uri_parameters' => @uri_parameters.map { |r| r.to_liquid },
          'query_parameters' => @query_parameters.map { |r| r.to_liquid },
          'responses' => @responses.map { |r| r.to_liquid }
        }
      end
    end
  end
end
