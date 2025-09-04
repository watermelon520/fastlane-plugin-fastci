lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/fastci/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-fastci'
  spec.version       = Fastlane::Fastci::VERSION
  spec.author        = 'watermelon'

  spec.summary       = 'Fast CI'
  # spec.homepage      = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-fastci"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'fastlane-plugin-pgyer'
  spec.add_dependency 'fastlane-plugin-versioning'
end
