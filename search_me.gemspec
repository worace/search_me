# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'search_me/version'

Gem::Specification.new do |spec|
  spec.name          = "search_me"
  spec.version       = SearchMe::VERSION
  spec.authors       = ["worace"]
  spec.email         = ["horace.d.williams@gmail.com"]
  spec.summary       = %q{CLI executable for a text-indexing exercise.}
  spec.description   = %q{run with `search_me <server_address>`}
  spec.homepage      = "https://github.com/worace/search_me"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.4"
  spec.add_dependency "rake", "~> 10.4"
end
