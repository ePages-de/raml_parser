module RamlParser
  class YamlNode
    attr_reader :parent, :key, :value

    def initialize(parent, key, value)
      @parent = parent
      @key = key
      @value = value
    end

    def root
      if @parent != nil
        @parent.root
      else
        self
      end
    end

    def path
      if @parent != nil
        "#{@parent.path}.#{@key}"
      else
        @key
      end
    end

    def or_default(default)
      @value != nil ? self : YamlNode.new(@parent, @key, default)
    end

    def array(index)
      new_node = YamlNode.new(self, "[#{index}]", @value[index])
      new_node
    end

    def array_map(&code)
      (@value || []).each_with_index.map { |_,i| code.call(array(i)) }
    end

    def hash(key)
      new_node = YamlNode.new(self, key, @value[key])
      new_node
    end

    def hash_map(&code)
      Hash[(@value || {}).map { |k,v| [k, code.call(hash(k))] }]
    end

    def arrayhash(index)
      new_node = array(index)
      new_node2 = new_node.hash(new_node.value.first[0])
      new_node2
    end

    def arrayhash_map(&code)
      Hash[(@value || []).each_with_index.map { |_,i|
        node = arrayhash(i)
        [node.key, code.call(node)]
      }]
    end
  end

  class YamlHelper
    require 'yaml'

    def self.read_yaml(path)
      # add support for !include tags
      Psych.add_domain_type 'include', 'include' do |_, value|
        case value
          when /^https?:\/\//
            # TODO implement remote loading of included files
            ''
          else
            case value
              when /\.raml$/
                read_yaml(value)
              when /\.ya?ml$/
                read_yaml(value)
              else
                File.read(value)
            end
        end
      end

      # change working directory so that !include works properly
      pwd_old = Dir.pwd
      Dir.chdir(File.dirname(path))
      raw = File.read(File.basename(path))
      node = YAML.load(raw)
      Dir.chdir(pwd_old)
      node
    end

    def self.dump_yaml(yaml)
      YAML.dump(yaml)
    end
  end
end
