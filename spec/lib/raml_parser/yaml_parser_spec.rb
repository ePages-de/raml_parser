require 'raml_parser/yaml_helper'

RSpec.describe RamlParser::YamlHelper do
  it 'reads simple YAML file' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/simple.yml')
    expect(yml['foo']).to eq 'bar'
  end

  it 'works with include tags' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/include1.yml')
    expect(yml['foo']).to eq 'bar'
    expect(yml['inner']['apple']).to eq 'pie'
  end
end

RSpec.describe RamlParser::YamlTree do
  it 'has a working map method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/simple.yml')
    tree = RamlParser::YamlTree.new(yml)

    expect(tree.root.map { |node| node.path }).to eq ['root.foo', 'root.empty']
    expect(tree.root.map { |node| node.value }).to eq ['bar', nil]
  end

  it 'has a working flatten method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/traversing.yml')
    tree = RamlParser::YamlTree.new(yml)

    expect(tree.flatten.map { |n| n.path }).to eq [
      'root',
      'root.string',
      'root.integer',
      'root.hash',
      'root.hash.apple',
      'root.array',
      'root.array.[0]',
      'root.array.[1]',
      'root.array.[1].bar',
      'root.array.[1].bar.sub'
    ]
  end
end
