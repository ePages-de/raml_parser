require 'raml_parser'

RSpec.describe RamlParser::Parser do
  all_errors = {
      :semantic_error => :error,
      :key_unknown => :error,
      :not_yet_supported => :error
  }

  it 'parses basic globals' do
    parser = RamlParser::Parser.new(all_errors)
    raml = parser.parse_file('spec/examples/raml/simple.raml')

    expect(raml.title).to eq 'Example API'
    expect(raml.base_uri).to eq 'http://localhost:3000'
    expect(raml.version).to eq 'v123'
  end

  it 'finds all resources' do
    parser = RamlParser::Parser.new(all_errors)
    raml = parser.parse_file('spec/examples/raml/resources.raml')

    expect(raml.resources.map { |r| r.absolute_uri }).to eq [
      'http://localhost:3000/first',
      'http://localhost:3000/first/second',
      'http://localhost:3000/third',
      'http://localhost:3000/with',
      'http://localhost:3000/with/{uri}',
      'http://localhost:3000/with/{uri}/{params}'
    ]
  end

  it 'parses URI parameters' do
    parser = RamlParser::Parser.new(all_errors)
    raml = parser.parse_file('spec/examples/raml/uriparameters.raml')

    expect(raml.resources[0].uri_parameters.map { |name,param| param.name }).to eq []
    expect(raml.resources[1].uri_parameters.map { |name,param| param.name }).to eq ['first']
    expect(raml.resources[2].uri_parameters.map { |name,param| param.name }).to eq ['first', 'second']
    expect(raml.resources[3].uri_parameters.map { |name,param| param.name }).to eq ['third']

    expect(raml.resources[2].uri_parameters['first'].display_name).to eq 'first'
    expect(raml.resources[2].uri_parameters['second'].display_name).to eq 'This is the second uri parameter'
  end

  it 'parses query parameters' do
    parser = RamlParser::Parser.new(all_errors)
    raml = parser.parse_file('spec/examples/raml/queryparameters.raml')

    expect(raml.resources[0].methods['get'].query_parameters.map { |name,_| name }).to eq ['q1']
    expect(raml.resources[0].methods['get'].query_parameters.map { |_,param| param.name }).to eq ['q1']
    expect(raml.resources[1].methods['get'].query_parameters.map { |name,_| name }).to eq ['q2']
    expect(raml.resources[1].methods['get'].query_parameters.map { |_,param| param.name }).to eq ['q2']

    expect(raml.resources[0].methods['get'].query_parameters['q1'].display_name).to eq 'q1'
    expect(raml.resources[1].methods['get'].query_parameters['q2'].display_name).to eq 'This is the second query parameter'
  end

  it 'parses traits' do
    parser = RamlParser::Parser.new
    raml = parser.parse_file('spec/examples/raml/traits.raml')

    expect(raml.traits.map { |name,_| name }).to eq ['searchable', 'sortable']
    expect(raml.traits.map { |_,trait| trait.name }).to eq ['searchable', 'sortable']
  end

  it 'parses responses' do
    parser = RamlParser::Parser.new(all_errors)
    raml = parser.parse_file('spec/examples/raml/responses.raml')

    expect(raml.resources[0].methods['get'].responses.map { |code,_| code }).to eq [200, 404]
    expect(raml.resources[0].methods['get'].responses.map { |_,res| res.status_code }).to eq [200, 404]

    expect(raml.resources[0].methods['get'].responses[200].bodies.map { |type,_| type }).to eq ['application/json', 'text/xml']
    expect(raml.resources[0].methods['get'].responses[200].bodies['application/json'].example).to_not eq nil
  end

  it 'mixes in traits' do
    parser = RamlParser::Parser.new
    raml = parser.parse_file('spec/examples/raml/traits.raml')

    expect(raml.resources[0].methods['get'].query_parameters.map { |name,_| name }).to eq ['q', 'key', 'order']
    expect(raml.resources[0].methods['get'].display_name).to eq 'Foo'
    expect(raml.resources[0].methods['get'].description).to eq 'This is sortable'

    expect(raml.resources[1].methods['get'].query_parameters.map { |name,_| name }).to eq ['q', 'key', 'order', 'sort']
    expect(raml.resources[1].methods['get'].display_name).to eq '/a/b'
    expect(raml.resources[1].methods['get'].description).to eq 'This is resource /a/b'
  end

  it 'does not fail on any example RAML file' do
    files = Dir.glob('spec/examples/raml/**/*.raml')
    parser = RamlParser::Parser.new({ :not_yet_supported => :ignore })

    files.each { |f|
      raml = parser.parse_file(f)
      raml.to_hash
    }
  end
end
