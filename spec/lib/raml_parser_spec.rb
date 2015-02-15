require 'raml_parser'

RSpec.describe RamlParser::Parser do
  it 'finds all resources' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    expect(raml.resources.map { |r| r.absolute_uri }).to eq [
        'http://localhost:3000/first',
        'http://localhost:3000/first/second',
        'http://localhost:3000/third',
        'http://localhost:3000/with',
        'http://localhost:3000/with/{uri}',
        'http://localhost:3000/with/{uri}/{params}'
    ]
  end

  it 'parses basic globals' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/simple.raml')
    expect(raml.title).to eq 'Example API'
    expect(raml.base_uri).to eq 'http://localhost:3000'
    expect(raml.version).to eq 'v123'
    expect(raml.media_type).to eq 'application/json'
  end

  it 'parses URI parameters' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/uriparameters.raml')
    expect(raml.resources[0].uri_parameters.map { |_,param| param.name }).to eq []
    expect(raml.resources[1].uri_parameters.map { |_,param| param.name }).to eq ['first']
    expect(raml.resources[2].uri_parameters.map { |_,param| param.name }).to eq ['second', 'first']
    expect(raml.resources[3].uri_parameters.map { |_,param| param.name }).to eq ['third']
    expect(raml.resources[2].uri_parameters['first'].display_name).to eq 'first'
    expect(raml.resources[2].uri_parameters['first'].type).to eq 'string'
    expect(raml.resources[2].uri_parameters['second'].display_name).to eq 'This is the second uri parameter'
    expect(raml.resources[2].uri_parameters['second'].type).to eq 'integer'
  end

  it 'parses query parameters' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/queryparameters.raml')
    expect(raml.resources[0].methods['get'].query_parameters.map { |name,_| name }).to eq ['q1']
    expect(raml.resources[0].methods['get'].query_parameters.map { |_,param| param.name }).to eq ['q1']
    expect(raml.resources[1].methods['get'].query_parameters.map { |name,_| name }).to eq ['q2']
    expect(raml.resources[1].methods['get'].query_parameters.map { |_,param| param.name }).to eq ['q2']
    expect(raml.resources[0].methods['get'].query_parameters['q1'].display_name).to eq 'q1'
    expect(raml.resources[0].methods['get'].query_parameters['q1'].type).to eq 'string'
    expect(raml.resources[1].methods['get'].query_parameters['q2'].display_name).to eq 'This is the second query parameter'
    expect(raml.resources[1].methods['get'].query_parameters['q2'].type).to eq 'integer'
  end

  it 'parses methods' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/methods.raml')
    expect(raml.resources[0].methods['get'].method).to eq 'GET'
    expect(raml.resources[0].methods['get'].display_name).to eq 'GET /a'
    expect(raml.resources[1].methods['get'].method).to eq 'GET'
    expect(raml.resources[1].methods['get'].display_name).to eq 'This is /a/b'
  end

  it 'parses responses' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/responses.raml')
    expect(raml.resources[0].methods['get'].responses.map { |code,_| code }).to eq [200, 404]
    expect(raml.resources[0].methods['get'].responses.map { |_,res| res.status_code }).to eq [200, 404]
  end

  it 'parses bodies' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/responses.raml')
    expect(raml1.resources[0].methods['get'].responses[200].bodies.map { |type,_| type }).to eq ['application/json', 'text/xml']
    expect(raml1.resources[0].methods['get'].responses[200].bodies['application/json'].example).to_not eq nil

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/requestbodies.raml')
    expect(raml2.resources[0].methods['post'].bodies.map { |type,_| type }).to eq ['application/json', 'text/xml']
    expect(raml2.resources[0].methods['put'].bodies['application/json'].example).to_not eq nil
  end

  it 'parses headers' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/headers.raml')
    expect(raml.resources[0].methods['get'].headers['X-Foobar-Ping'].description).to eq 'Ping'
    expect(raml.resources[0].methods['get'].responses[200].headers['X-Foobar-Pong'].description).to eq 'Pong'
  end

  it 'parses form parameters' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/formparameters.raml')
    expect(raml.resources[0].methods['post'].bodies['application/x-www-form-urlencoded'].form_parameters['from'].description).to eq 'FROM1'
    expect(raml.resources[0].methods['post'].bodies['application/x-www-form-urlencoded'].form_parameters['to'].description).to eq 'TO1'
    expect(raml.resources[1].methods['post'].bodies['multipart/form-data'].form_parameters['from'].description).to eq 'FROM2'
    expect(raml.resources[1].methods['post'].bodies['multipart/form-data'].form_parameters['to'].description).to eq 'TO2'
  end

  it 'parses security schemes' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/securityschemes.raml')
    expect(raml.security_schemes.keys).to eq ['oauth_2_0', 'oauth_1_0', 'customHeader']
    expect(raml.security_schemes['oauth_2_0'].type).to eq 'OAuth 2.0'
    expect(raml.security_schemes['oauth_1_0'].type).to eq 'OAuth 1.0'
    expect(raml.security_schemes['customHeader'].type).to eq nil
  end

  it 'parses documentation' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/documentation.raml')
    expect(raml.documentation[0].title).to eq 'Home'
    expect(raml.documentation[1].title).to eq 'FAQ'
  end

  it 'handle secured by' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/securedby1.raml')
    expect(raml1.resources[0].methods['get'].secured_by).to eq ['oauth_1_0']
    expect(raml1.resources[0].methods['post'].secured_by).to eq ['oauth_2_0']
    expect(raml1.resources[1].methods['get'].secured_by).to eq ['oauth_1_0', nil, 'oauth_2_0']
    expect(raml1.resources[1].methods['post'].secured_by).to eq ['oauth_1_0', 'oauth_2_0']

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/securedby2.raml')
    expect(raml2.resources[0].methods['get'].secured_by).to eq ['oauth_2_0', 'oauth_1_0']
    expect(raml2.resources[0].methods['post'].secured_by).to eq ['oauth_2_0']
    expect(raml2.resources[1].methods['get'].secured_by).to eq ['oauth_2_0', 'oauth_1_0', nil]
    expect(raml2.resources[1].methods['post'].secured_by).to eq ['oauth_2_0', 'oauth_1_0']
  end

  it 'mixes in traits' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/traits.raml')
    expect(raml.resources[0].methods['get'].query_parameters.map { |name,_| name }).to eq ['q', 'key', 'order']
    expect(raml.resources[0].methods['get'].display_name).to eq 'Foo'
    expect(raml.resources[0].methods['get'].description).to eq 'This is sortable'
    expect(raml.resources[1].methods['get'].query_parameters.map { |name,_| name }).to eq ['q', 'key', 'order', 'sort']
    expect(raml.resources[1].methods['get'].display_name).to eq '/a/b'
    expect(raml.resources[1].methods['get'].description).to eq 'This is resource /a/b'
    expect(raml.resources[2].methods['get'].query_parameters.map { |name,_| name }).to eq ['key', 'order']
    expect(raml.resources[3].methods['get'].query_parameters.map { |name,_| name }).to eq ['key', 'order', 'q']
  end

  it 'mixes in resource types' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/resourcetypes.raml')
    expect(raml.resources[0].methods.keys).to eq ['get', 'post', 'put']
    expect(raml.resources[0].methods['get'].description).to eq 'Get all items'
    expect(raml.resources[0].methods['post'].description).to eq 'Overriden'
    expect(raml.resources[0].methods['put'].description).to eq nil
  end

  it 'falls back to default display name' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    expect(raml1.resources[1].display_name).to eq '/first/second'
    expect(raml1.resources[2].display_name).to eq 'This is the third'

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    expect(raml2.resources[5].uri_parameters['uri'].display_name).to eq 'uri'
    expect(raml2.resources[5].uri_parameters['params'].display_name).to eq 'This are the params'

    raml3 = RamlParser::Parser.parse_file('spec/examples/raml/queryparameters.raml')
    expect(raml3.resources[0].methods['get'].query_parameters['q1'].display_name).to eq 'q1'
    expect(raml3.resources[1].methods['get'].query_parameters['q2'].display_name).to eq 'This is the second query parameter'

    raml4 = RamlParser::Parser.parse_file('spec/examples/raml/methods.raml')
    expect(raml4.resources[0].methods['get'].display_name).to eq 'GET /a'
    expect(raml4.resources[1].methods['get'].display_name).to eq 'This is /a/b'

    raml5 = RamlParser::Parser.parse_file('spec/examples/raml/headers.raml')
    expect(raml5.resources[0].methods['get'].headers['X-Foobar-Ping'].display_name).to eq 'X-Foobar-Ping'
    expect(raml5.resources[0].methods['get'].responses[200].headers['X-Foobar-Pong'].display_name).to eq 'PingPong'
  end

  it 'fixed issue #2' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/issue2.raml')
    expect(raml.resources[0].methods.keys).to eq ['post', 'get']
    expect(raml.resources[0].methods['get'].method).to eq 'GET'
    expect(raml.resources[0].methods['post'].method).to eq 'POST'
  end

  it 'handles parametrization of traits and resource types' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/parameters.raml')
    expect(raml.resources[0].methods['get'].description).to eq '/first and first and get and Hello'
    expect(raml.resources[0].methods['get'].query_parameters['get'].description).to eq 'Applepie'
    expect(raml.resources[1].description).to eq '/second and second and World'
    expect(raml.resources[3].description).to eq '/third/fourth and fourth and Finish'
  end

  it 'handles singularization/pluralization of parametrization' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/parametersinflection.raml')

    expect(raml.resources[0].methods['get'].description).to eq 'Keep userName'
    expect(raml.resources[0].methods['post'].description).to eq 'Plu userNames'
    expect(raml.resources[1].methods['get'].description).to eq 'Keep passwords'
    expect(raml.resources[1].methods['post'].description).to eq 'Sing password'
  end

  it 'does not fail on any example RAML file' do
    files = Dir.glob('spec/examples/raml/**/*.raml')
    files.each { |f|
      known_unused = %w()
      known_unsupported = %w(root.schemas .describedBy .someMultipartFormParamWithMultipleTypes)

      result = RamlParser::Parser.parse_file_with_marks(f)
      unused = result[:marks].select { |_,m| m == :unused }
      unsupported = result[:marks].select { |_,m| m == :unsupported }

      expect(unused.select { |p,_| not known_unused.any? { |k| p.include? k} }.length).to eq 0
      expect(unsupported.select { |p,_| not known_unsupported.any? { |k| p.include? k} }.length).to eq 0
    }
  end
end
