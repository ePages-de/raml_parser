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
    expect(raml.resources[2].uri_parameters.map { |_,param| param.name }).to eq ['first', 'second']
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
    expect(raml.resources[1].methods['get'].method).to eq 'GET'
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

    expect(raml.security_schemes['oauth_2_0'].settings['authorizationUri']).to eq 'https://www.dropbox.com/1/oauth2/authorize'
    expect(raml.security_schemes['oauth_2_0'].described_by.headers['Authorization'].description).to start_with 'Used to send'
  end

  it 'parses documentation' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/documentation.raml')
    expect(raml.documentation[0].title).to eq 'Home'
    expect(raml.documentation[1].title).to eq 'FAQ'
  end

  it 'parses schemas' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/schemas.raml')
    expect(raml.schemas['schema1']).to start_with '<?xml version="1.1"?>'
    expect(raml.schemas['schema2']).to start_with '<?xml version="1.2"?>'
    expect(raml.resources[0].methods['get'].bodies['text/xml'].schema).to start_with '<?xml version="1.1"?>'
    expect(raml.resources[0].methods['post'].bodies['text/xml'].schema).to start_with '<?xml version="1.2"?>'
    expect(raml.resources[0].methods['put'].bodies['text/xml'].schema).to start_with '<?xml version="1.3"?>'
  end

  it 'parses base URI parameters' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/baseuriparameters1.raml')
    expect(raml1.resources[0].absolute_uri).to eq 'http://localhost:3000/v4/a'
    expect(raml1.base_uri_parameters).to eq ({})

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/baseuriparameters2.raml')
    expect(raml2.base_uri_parameters.map { |_,p| p.name }).to eq ['user', 'language']
    expect(raml2.resources[0].uri_parameters.map { |_,p| p.name }).to eq []
    expect(raml2.resources[0].base_uri_parameters.map { |_,p| p.name }).to eq ['user', 'language']
    expect(raml2.resources[1].uri_parameters.map { |_,p| p.name }).to eq ['next']
    expect(raml2.resources[1].base_uri_parameters.map { |_,p| p.name }).to eq ['user', 'language']
    expect(raml2.resources[2].uri_parameters.map { |_,p| p.name }).to eq ['next']
    expect(raml2.resources[2].base_uri_parameters.map { |_,p| p.name }).to eq ['user', 'language']
    expect(raml2.resources[0].base_uri_parameters['user'].description).to eq 'The user'
    expect(raml2.resources[1].base_uri_parameters['user'].description).to eq 'The user'
    expect(raml2.resources[2].base_uri_parameters['user'].description).to eq 'Changed'
  end

  it 'parses protocols' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/protocols1.raml')
    expect(raml1.protocols).to eq []
    expect(raml1.resources[0].methods['get'].protocols).to eq %w()
    expect(raml1.resources[1].methods['get'].protocols).to eq %w(HTTP HTTPS)
    expect(raml1.resources[2].methods['get'].protocols).to eq %w(HTTP)
    expect(raml1.resources[3].methods['get'].protocols).to eq %w(HTTPS)

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/protocols2.raml')
    expect(raml2.protocols).to eq ['HTTP']
    expect(raml2.resources[0].methods['get'].protocols).to eq %w(HTTP)
    expect(raml2.resources[1].methods['get'].protocols).to eq %w(HTTP HTTPS)
    expect(raml2.resources[2].methods['get'].protocols).to eq %w(HTTP)
    expect(raml2.resources[3].methods['get'].protocols).to eq %w(HTTPS)

    raml3 = RamlParser::Parser.parse_file('spec/examples/raml/protocols3.raml')
    expect(raml3.protocols).to eq ['HTTP', 'HTTPS']
    expect(raml3.resources[0].methods['get'].protocols).to eq %w(HTTP HTTPS)
    expect(raml3.resources[1].methods['get'].protocols).to eq %w(HTTP HTTPS)
    expect(raml3.resources[2].methods['get'].protocols).to eq %w(HTTP)
    expect(raml3.resources[3].methods['get'].protocols).to eq %w(HTTPS)
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
    expect(raml.resources[0].methods['get'].description).to eq 'This is sortable'
    expect(raml.resources[1].methods['get'].query_parameters.map { |name,_| name }).to eq ['q', 'key', 'order', 'sort']
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

    raml4 = RamlParser::Parser.parse_file('spec/examples/raml/headers.raml')
    expect(raml4.resources[0].methods['get'].headers['X-Foobar-Ping'].display_name).to eq 'X-Foobar-Ping'
    expect(raml4.resources[0].methods['get'].responses[200].headers['X-Foobar-Pong'].display_name).to eq 'PingPong'
  end

  it 'properly sets required property' do
    raml = RamlParser::Parser.parse_file('spec/examples/raml/required.raml')
    expect(raml.resources[0].uri_parameters['b'].required).to eq true
    expect(raml.resources[1].uri_parameters['d'].required).to eq true
    expect(raml.resources[2].uri_parameters['f'].required).to eq false
    expect(raml.resources[3].uri_parameters['h'].required).to eq true
    expect(raml.resources[4].methods['get'].query_parameters['j'].required).to eq false
    expect(raml.resources[4].methods['get'].query_parameters['k'].required).to eq false
    expect(raml.resources[4].methods['get'].query_parameters['l'].required).to eq true
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
      result = RamlParser::Parser.parse_file_with_marks(f)

      expect(result[:marks]).to all(satisfy do |p,m|
        m == :used or m == :unsupported
      end)
    }
  end

  it 'fail on any bad example RAML file' do
    files = Dir.glob('spec/examples/raml_bad/**/*.raml')
    files.each { |f|
      expect { RamlParser::Parser.parse_file_with_marks(f) }.to raise_error
    }
  end
end
