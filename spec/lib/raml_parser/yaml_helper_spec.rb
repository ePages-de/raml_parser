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

RSpec.describe RamlParser::YamlNode do
  it 'has a working array/array_map method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/traversing.yml')
    root = RamlParser::YamlNode.new(nil, 'root', yml)
    expect(root.hash('array').array(0).value).to eq 'foo'
    expect(root.hash('array').array_values { |n| n.key }).to eq ['[0]', '[1]']
  end

  it 'has a working hash/hash_map method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/traversing.yml')
    root = RamlParser::YamlNode.new(nil, 'root', yml)
    expect(root.hash('integer').value).to eq 10
    expect(root.hash_values { |n| 0 }).to eq ({'string'=>0, 'integer'=>0, 'hash'=>0, 'array'=>0, 'array_complex'=>0})
  end

  it 'has a working arrayhash/arrayhash_map method' do
    yml = RamlParser::YamlHelper.read_yaml('spec/examples/yaml/traversing.yml')
    root = RamlParser::YamlNode.new(nil, 'root', yml)
    expect(root.hash('array_complex').arrayhash(0).key).to eq 'foo'
    expect(root.hash('array_complex').arrayhash(0).value).to eq nil
    expect(root.hash('array_complex').arrayhash_values { |n| n.value }).to eq ({'foo'=>nil, 'bar'=>{'sub'=>'element'}})
  end

  it 'merge deep' do
    def example(left, right, expect)
      expect(RamlParser::YamlHelper::merge_deep(left, right)).to eq expect
    end

    example(1, 2, 2)
    example(2, 1, 1)
    example('a', 'b', 'b')
    example('b', 'a', 'a')
    example([1, 2], [3, 4], [1, 2, 3, 4])
    example([1, 2], [2, 3], [1, 2, 3])
    example([4, 1], [3, 2], [4, 1, 3, 2])
    example({:a => 'b'}, {:c => 'd'}, {:a => 'b', :c => 'd'})
    example({:a => 'b'}, {:a => 'c'}, {:a => 'c'})
    example({:a => {:b => 'c'}}, {:a => {:d => 'e'}}, {:a => {:b => 'c', :d => 'e'}})
    example({:a => {:b => {:c => 'd'}}}, {:a => {:b => {:e => 'f'}}}, {:a => {:b => {:c => 'd', :e => 'f'}}})
    example({}, {:a => 'b'}, { :a => 'b'})
    example({}, {:a => {:b => 'c'}}, {:a => {:b => 'c'}})
  end
end
