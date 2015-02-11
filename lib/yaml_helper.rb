module RamlParser
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
