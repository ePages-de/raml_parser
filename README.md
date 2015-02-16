# RamlParser

[![build](https://img.shields.io/travis/ePages-de/raml_parser/develop.svg)](https://travis-ci.org/ePages-de/raml_parser)
[![gem](https://img.shields.io/gem/v/raml_parser.svg)](https://rubygems.org/gems/raml_parser)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](http://opensource.org/licenses/MIT)

A parser for the [RAML](http://raml.org/) API modeling language.

## Installation

Add this line to your application's Gemfile:

```ruby
source 'https://rubygems.org'

gem 'raml_parser'
```

And then execute:

    $ bundle

## Usage

```ruby
require 'raml_parser'

raml = RamlParser::Parser.parse_file('path/to/api.raml')

# generate some markdown out of it
for res in raml.resources
  puts '# Resource ' + res.absolute_uri + "\n\n"
  for name, meth in res.methods
    puts '## Method ' + meth.method + "\n\n"
    unless meth.description.nil?
      puts meth.description + "\n\n"
    else
      puts "(TODO)\n\n"
    end
  end
end
```

## What parts of RAML are not supported

These are features of the RAML 0.8 specification that are not fully handled yet. This list should be complete, i.e. everything not listed here should work.

* [Named parameters with multiple types](http://raml.org/spec.html#named-parameters-with-multiple-types)
* [Optional properties in resource types](http://raml.org/spec.html#optional-properties)

## Contributing

1. Fork it ( https://github.com/ePages-de/raml_parser/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
