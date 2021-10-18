# frozen_string_literal: true

require_relative 'lib/konfipay/version'

Gem::Specification.new do |spec|
  spec.name          = "konfipay"
  spec.version       = Konfipay::VERSION
  spec.authors       = ["Pessi Virta", 'Martin Tepper']
  spec.email         = ["development@mein-grundeinkommen.de"]
  spec.license       = 'MIT'

  spec.summary       = 'A Ruby wrapper for the Konfipay API'
  # spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://github.com/MeinGrundeinkommen/konfipay"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MeinGrundeinkommen/konfipay"
  spec.metadata["changelog_uri"] = "https://github.com/MeinGrundeinkommen/konfipay/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_dependency 'pry'
  spec.add_dependency "camt_parser"
  spec.add_dependency "sepa_king"
  spec.add_dependency "http"
  spec.add_dependency "json"
end
