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
      "OPTIONS http://example.com/resource",
      "CONNECT http://example.com/resource",
      "TRACE http://example.com/resource",
      "PATCH http://example.com/resource",
      "DELETE http://example.com/resource",
      "PUT http://example.com/resource",
      "GET http://example.com/resource",
      "GET http://example.com/resource/{resourceId}",
      "POST http://example.com/resource/{resourceId}",
      "CONNECT http://example.com/another/resource",
      "HEAD http://example.com/another/resource",
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
    expect(raml.resources[6].description).to eq 'get the first one'
  end

  it 'does not fail on any example RAML file' do
    files = Dir.glob('spec/examples/raml/*.raml')
    parser = RamlParser::Parser.new('ignore')

    files.each { |f|
      parser.parse_file(f)
    }
  end

  it 'finds URI parameters' do
    parser = RamlParser::Parser.new(unknown_handling)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.resources[7].uri_parameters.map { |p| p.name }).to eq ['resourceId']
  end

  it 'finds query parameters' do
    parser = RamlParser::Parser.new(unknown_handling)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.resources[7].query_parameters.map { |p| p.name }).to eq ['filter']
  end
end
