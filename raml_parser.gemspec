Gem::Specification.new do |s|
  s.name        = 'raml_parser'
  s.version     = '0.0.1.pre'
  s.date        = '2015-02-11'
  s.summary     = 'A parser for RAML API specifications'
  s.description = 'A parser for RAML API specifications'
  s.authors     = ['Christian Hoffmeister']
  s.email       = 'mail@choffmeister.de'
  s.files       = [
    'lib/raml_parser.rb',
    'lib/yaml_helper.rb',
    'lib/model/root.rb',
    'lib/model/resource.rb',
    'lib/model/response.rb',
    'lib/model/named_parameter.rb'
  ]
  s.homepage    = 'https://github.com/epages-de/raml_parser'
  s.license     = 'MIT'
end
