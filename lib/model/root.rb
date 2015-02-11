require 'yaml_helper'

module RamlParser
  module Model
    class Root
      attr_accessor :title, :base_uri, :version, :traits, :resources

      def initialize
        @title = '(unnamed)'
        @base_uri = ''
        @traits = {}
        @resources = []
      end

      def to_liquid
        {
          'title' => @title,
          'base_uri' => @base_uri,
          'version' => @version,
          'resources' => @resources.map { |r| r.to_liquid }
        }
      end
    end
  end
end
