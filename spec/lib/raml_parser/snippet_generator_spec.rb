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

  it 'generate javascript vanilla snippets' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    gen1 = RamlParser::SnippetGenerator.new(raml1)
    res1 = gen1.javascript_vanilla(raml1.resources[0], 'get')
    expect(res1).to include 'GET'
    expect(res1).to include 'http://localhost:3000/first'

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/requestbodies.raml')
    gen2 = RamlParser::SnippetGenerator.new(raml2)
    res2 = gen2.javascript_vanilla(raml2.resources[0], 'post')
    expect(res2).to include 'Accept'
    expect(res2).to include 'application/json'
    expect(res2).to include '"foo": "bar"'

    raml3 = RamlParser::Parser.parse_file('spec/examples/raml/required.raml')
    gen3 = RamlParser::SnippetGenerator.new(raml3)
    res3 = gen3.javascript_vanilla(raml3.resources[4], 'get')
    expect(res3).to include 'GET'
    expect(res3).to include 'http://localhost:3000/i?l=value'
  end

  it 'generate ruby snippets' do
    raml1 = RamlParser::Parser.parse_file('spec/examples/raml/resources.raml')
    gen1 = RamlParser::SnippetGenerator.new(raml1)
    res1 = gen1.ruby(raml1.resources[0], 'get')
    expect(res1).to include 'Net::HTTP::Get'
    expect(res1).to include 'http://localhost:3000/first'

    raml2 = RamlParser::Parser.parse_file('spec/examples/raml/requestbodies.raml')
    gen2 = RamlParser::SnippetGenerator.new(raml2)
    res2 = gen2.ruby(raml2.resources[0], 'post')
    expect(res2).to include 'Net::HTTP::Post'
    expect(res2).to include 'Accept'
    expect(res2).to include 'application/json'
    expect(res2).to include '"foo": "bar"'

    raml3 = RamlParser::Parser.parse_file('spec/examples/raml/required.raml')
    gen3 = RamlParser::SnippetGenerator.new(raml3)
    res3 = gen3.ruby(raml3.resources[4], 'get')
    expect(res3).to include 'Net::HTTP::Get'
    expect(res3).to include 'http://localhost:3000/i?l=value'
  end
end
