require 'raml_parser/snippet_generator'

RSpec.describe RamlParser::SnippetGenerator do
  it 'generate curl snippets' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    gen1 = RamlParser::SnippetGenerator.new(raml1)
    res1 = gen1.curl(raml1.resources[0], 'get')
    expect(res1).to eq 'curl -XGET http://localhost:3000/first'

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/requestbodies.raml')
    gen2 = RamlParser::SnippetGenerator.new(raml2)
    res2 = gen2.curl(raml2.resources[0], 'post')
    expect(res2).to include '-XPOST'
    expect(res2).to include 'Accept: application/json'
    expect(res2).to include '"foo": "bar"'

    raml3 = RamlParser::Parser.parse_file('spec/examples/raml/required.raml')
    gen3 = RamlParser::SnippetGenerator.new(raml3)
    res3 = gen3.curl(raml3.resources[4], 'get')
    expect(res3).to eq 'curl -XGET http://localhost:3000/i?l=value'
  end
end
