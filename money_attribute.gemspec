# frozen_string_literal: true

require_relative 'lib/money_attribute/version'

Gem::Specification.new do |spec|
  spec.name        = 'money_attribute'
  spec.version     = MoneyAttribute::VERSION
  spec.authors     = ['Gilson Ferraz']
  spec.email       = ['gilson@cesar.etc.br']
  spec.homepage    = 'https://github.com/gferraz/money-attribute'
  spec.summary     = 'Money attributes for ActiveRecord'
  spec.description = 'Easily add money attributes to your Rails models'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/releases"
  spec.metadata['bug_tracker_uri'] = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob('{app,config,db,lib}/**/*', base: __dir__) + %w[MIT-LICENSE Rakefile README.md]

  spec.required_ruby_version = '>= 3.3'

  spec.add_dependency 'minting', '>= 1.9.0'
  spec.add_dependency 'rails', '>= 7.1.3.2'
end
