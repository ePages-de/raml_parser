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
