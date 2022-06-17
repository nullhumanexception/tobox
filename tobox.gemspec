# frozen_string_literal: true

require_relative "lib/tobox/version"

Gem::Specification.new do |spec|
  spec.name = "tobox"
  spec.version = Tobox::VERSION
  spec.authors = ["HoneyryderChuck"]
  spec.email = ["cardoso_tiago@hotmail.com"]

  spec.summary = "Transactional outbox pattern implementation in ruby"
  spec.description = "Transactional outbox pattern implementation in ruby"
  spec.homepage = "https://gitlab.com/honeyryderchuck/tobox"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://gitlab.com/honeyryderchuck/tobox"
  spec.metadata["changelog_uri"] = "https://gitlab.com/honeyryderchuck/tobox/-/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["LICENSE.txt", "README.md", "lib/**/*.rb", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", ">= 4.35"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
