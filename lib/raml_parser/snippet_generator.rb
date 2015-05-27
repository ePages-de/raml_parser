module RamlParser
  class SnippetGenerator
    attr_accessor :raml

    def initialize(raml)
      @raml = raml
    end

    def curl(resource, method_name)
      method = resource.methods[method_name]

      curl_method = "-X#{method.method.upcase}"
      curl_content_type = map_nonempty(method.bodies.values.first) { |b| "-H \"Accept: #{b.media_type}\"" }
      curl_query_parameters = map_nonempty(method.query_parameters.values
        .select { |q| q.required }
        .map { |q| "#{q.name}=#{q.example || 'value'}"}
        .join('&')) { |s| '?' + s }
      curl_data = map_nonempty(method.bodies.values.first) { |b| "-d \"#{b.example}\"" }

      ['curl', curl_method, curl_content_type, resource.absolute_uri + curl_query_parameters, curl_data].select { |p| not is_falsy(p) }.join(' ')
    end

    private
    def is_falsy(value)
      if value.is_a?(String)
        value.length == 0
      else
        value.nil?
      end
    end

    def map_nonempty(value, &code)
      if not is_falsy(value)
        code.call(value)
      else
        value
      end
    end
  end
end
