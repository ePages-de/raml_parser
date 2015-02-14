# RamlParser

[![build](https://img.shields.io/travis/ePages-de/raml_parser/develop.svg)](https://travis-ci.org/ePages-de/raml_parser)
[![license](http://img.shields.io/badge/license-MIT-lightgrey.svg)](http://opensource.org/licenses/MIT)

A parser for the [RAML](http://raml.org/) API modeling language.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'raml_parser', :git => 'https://github.com/ePages-de/raml_parser.git', :branch => 'master'
```

And then execute:

    $ bundle

## Usage

TODO: Write usage instructions here

## What parts of RAML are not supported

These are features of the RAML 0.8 specification that are not fully handled yet. This list should be complete, i.e. everything not listed here should work.

* [Parametrized traits](http://raml.org/spec.html#resource-types-and-traits)
* [Resource types](http://raml.org/spec.html#resource-types-and-traits)
* [Security](http://raml.org/spec.html#security)
* [Schemas](http://raml.org/spec.html#schemas)
* [Headers](http://raml.org/spec.html#headers)
* [Protocols](http://raml.org/spec.html#protocols)
* [Default Media Type](http://raml.org/spec.html#default-media-type)
* [Media type extension URI parameters](http://raml.org/spec.html#template-uris-and-uri-parameters)

## Contributing

1. Fork it ( https://github.com/ePages-de/raml_parser/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
