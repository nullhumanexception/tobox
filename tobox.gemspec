# frozen_string_literal: true

require_relative "lib/tobox/version"

Gem::Specification.new do |spec|
  spec.name = "tobox"
  spec.version = Tobox::VERSION
  spec.authors = ["HoneyryderChuck"]
  spec.email = ["cardoso_tiago@hotmail.com"]

  spec.summary = "Transactional outbox pattern implementation in ruby"
  spec.description = "Transactional outbox pattern implementation in ruby"
  spec.homepage = "https://gitlab.com/os85/tobox"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "allowed_push_host" => "https://rubygems.org",
    "source_code_uri" => "https://gitlab.com/os85/tobox",
    "bug_tracker_uri" => "https://gitlab.com/os85/tobox/issues",
    "documentation_uri" => "https://gitlab.com/os85/tobox",
    "changelog_uri" => "https://gitlab.com/os85/tobox/-/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true"
  }
  spec.required_ruby_version = ">= 2.6.0"

  spec.require_paths = ["lib"]
  spec.files = Dir["LICENSE.txt", "README.md", "lib/**/*.rb", "exe/**", "CHANGELOG.md"]
  spec.bindir = "exe"
  spec.executables = ["tobox"]

  spec.add_dependency "sequel", ">= 4.35"

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
