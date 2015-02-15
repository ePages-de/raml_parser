module RamlParser
  class YamlTree
    attr_reader :root

    def initialize(root)
      @root = YamlNode.new(nil, 'root', root)
    end

    def flatten
      def recursion(current)
        [current] + current.map { |n| recursion(n) }
      end

      recursion(@root).flatten
    end
  end

  class YamlNode
    attr_reader :parent, :key, :value
    attr_accessor :data

    def initialize(parent, key, value, data = nil)
      @parent = parent
      @key = key
      @value = value
      @data = nil
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

    def each(&code)
      self.map(&code)
      return
    end

    def map(&code)
      if @value.is_a? Hash
        @value.map { |k,v|
          next_node = YamlNode.new(self, k, v)
          code.call(next_node)
        }
      elsif @value.is_a? Array
        @value.each_with_index.map { |v,i|
          next_node = YamlNode.new(self, "[#{i}]", v)
          code.call(next_node)
        }
      else
        []
      end
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
