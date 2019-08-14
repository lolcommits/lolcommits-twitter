lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lolcommits/twitter/version'

Gem::Specification.new do |spec|
  spec.name        = "lolcommits-twitter"
  spec.version     = Lolcommits::Twitter::VERSION
  spec.authors     = ["Matthew Hutchinson"]
  spec.email       = ["matt@hiddenloop.com"]
  spec.summary     = %q{Post lolcommits to Twitter}
  spec.homepage    = "https://github.com/lolcommits/lolcommits-twitter"
  spec.license     = "LGPL-3.0"
  spec.description = %q{Automatically tweet your lolcommits}

  spec.metadata = {
    "homepage_uri"      => "https://github.com/lolcommits/lolcommits-twitter",
    "changelog_uri"     => "https://github.com/lolcommits/lolcommits-twitter/blob/master/CHANGELOG.md",
    "source_code_uri"   => "https://github.com/lolcommits/lolcommits-twitter",
    "bug_tracker_uri"   => "https://github.com/lolcommits/lolcommits-twitter/issues",
    "allowed_push_host" => "https://rubygems.org"
  }

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(assets|test|features)/}) }
  spec.test_files    = `git ls-files -- {test,features}/*`.split("\n")
  spec.bindir        = "bin"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.3"

  spec.add_runtime_dependency "rest-client", '1.6.10'
  spec.add_runtime_dependency "oauth"
  spec.add_runtime_dependency "simple_oauth"
  spec.add_runtime_dependency "addressable"
  spec.add_runtime_dependency "lolcommits", ">= 0.14.2"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "webmock"
  spec.add_development_dependency "pry"
end
