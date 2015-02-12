require 'yaml_helper'

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
  it 'has a working maps method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/simple.yml')
    tree = RamlParser::YamlTree.new(yml)

    expect(tree.root.map { |node| node.path }).to eq ['root.foo', 'root.empty']
    expect(tree.root.map { |node| node.value }).to eq ['bar', nil]
  end

  it 'has a working each method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/simple.yml')
    tree = RamlParser::YamlTree.new(yml)

    result1 = []
    tree.root.each { |node| result1 << node.path }
    expect(result1).to eq ['root.foo', 'root.empty']

    result2 = []
    tree.root.each { |node| result2 << node.value }
    expect(result2).to eq ['bar', nil]
  end
end
