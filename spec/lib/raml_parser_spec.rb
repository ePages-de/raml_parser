require 'raml_parser'

RSpec.describe RamlParser::Parser do
  unknown_handling = 'ignore'

  it 'parses basic globals' do
    parser = RamlParser::Parser.new(unknown_handling)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.title).to eq 'Example API'
    expect(raml.base_uri).to eq 'http://example.com'
    expect(raml.version).to eq nil
  end

  it 'finds all resources' do
    parser = RamlParser::Parser.new(unknown_handling)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.resources.map { |r| "#{r.method.upcase} #{r.uri}" }).to eq [
      "DELETE http://example.com/resource",
      "PUT http://example.com/resource",
      "GET http://example.com/resource",
      "GET http://example.com/resource/{resourceId}",
      "POST http://example.com/resource/{resourceId}",
      "GET http://example.com/another/resource",
      "GET http://example.com/resource-with-headers",
      "GET http://example.com/secured-resource",
      "GET http://example.com/resource-with-method-level-traits",
      "GET http://example.com/resource-with-form-and-multipart-form-parameters",
      "POST http://example.com/resource-with-repeatable-params"
    ]
  end

  it 'mixes in unparametrized traits' do
    parser = RamlParser::Parser.new(unknown_handling)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.resources[0].description).to eq 'Some requests require authentication'
    expect(raml.resources[1].description).to eq 'Some requests require authentication'
    expect(raml.resources[2].description).to eq 'get the first one'
  end
end
