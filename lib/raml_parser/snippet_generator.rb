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
      query_parameters = map_nonempty(render_query_parameters(method.query_parameters.values)) { |s| '?' + s }
      curl_data = map_nonempty(method.bodies.values.first) { |b| "-d \"#{b.example}\"" }

      ['curl', curl_method, curl_content_type, resource.absolute_uri + query_parameters, curl_data].select { |p| not is_falsy(p) }.join(' ')
    end

    def javascript_vanilla(resource, method_name)
      method = resource.methods[method_name]

      query_parameters = map_nonempty(render_query_parameters(method.query_parameters.values)) { |s| '?' + s }
      js_content_type = map_nonempty(method.bodies.values.first) { |b| "xhr.setRequestHeader('Accept', '#{b.media_type}');\n" } || ''
      data = map_nonempty(method.bodies.values.first) { |b| (b.example || '').chop }

      result = "var xhr = new XMLHttpRequest();\n"
      result += "xhr.open('#{method.method.upcase}', '#{resource.absolute_uri + query_parameters}', true);\n"
      result += "xhr.onreadystatechange = function () {\n"
      result += "  if (xhr.readyState != 4 || xhr.status != 200) return;\n"
      result += "  console.log('Success', xhr.responseText);\n"
      result += "};\n"
      result += js_content_type
      result += "xhr.send(\"#{data}\");"

      result
    end

    def ruby(resource, method_name)
      method = resource.methods[method_name]
      send_method = method.method.downcase == 'post' || method.method.downcase == 'put'
      query_parameters = map_nonempty(render_query_parameters(method.query_parameters.values)) { |s| '?' + s } || ''
      uri = "#{resource.absolute_uri}#{query_parameters}"

      data = map_nonempty(method.bodies.values.first) { |b| b.example.chop }
      headers = { 'Accept' => map_nonempty(method.bodies.values.first) { |b| b.media_type } }
      headers = headers.delete_if {|key, value| value.nil? }

      result = "require 'net/http'\n"
      result += "require 'json'\n" if send_method
      result += "uri = URI.parse('#{uri}')\n"
      result += "headers = #{headers}\n" unless headers.empty?
      result += "data = #{data}\n\n" if send_method
      result += "req = Net::HTTP::#{method.method.capitalize}.new(uri.path"
      result += headers.empty? ? ")\n" : ", initheader = headers)\n"
      result += "req.body = data.to_json\n" if send_method
      result += "response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }\n"

      result
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

    def render_query_parameters(query_parameters)
      query_parameters
        .select { |q| q.required }
        .map { |q| "#{q.name}=#{q.example || 'value'}"}
        .join('&')
    end
  end
end
