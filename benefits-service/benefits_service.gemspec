# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'benefits_service/version'

Gem::Specification.new do |spec|
  spec.name          = "benefits_service"
  spec.version       = BenefitsService::VERSION
  spec.authors       = ["WellMatch Workstation"]
  spec.email         = ["dev@wellmatchhealth.com"]
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'celluloid-io'
  spec.add_dependency 'daemonize'
  spec.add_dependency 'thor'
  spec.add_dependency 'bunny'

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rspec-collection_matchers'
  spec.add_development_dependency 'guard'
  spec.add_development_dependency 'guard-rspec'
  spec.add_development_dependency 'guard-minitest'
end
