# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'raml_parser/version'

Gem::Specification.new do |spec|
  spec.name          = "raml_parser"
  spec.version       = RamlParser::VERSION
  spec.authors       = ["Christian Hoffmeister"]
  spec.email         = ["mail@choffmeister.de"]
  spec.summary       = "A parser for the RAML API modeling language."
  spec.description   = ""
  spec.homepage      = "https://github.com/ePages-de/raml_parser"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.2.0"

  spec.add_dependency "activesupport", ">= 4.0.0"
end
