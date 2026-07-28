# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in money_attribute.gemspec.
gemspec

gem 'minting'

gem 'puma'
gem 'sqlite3', '>= 2.0'

case ENV.fetch('DATABASE_ADAPTER', 'sqlite3')
when 'postgresql'
  gem 'pg'
when 'mysql2'
  gem 'mysql2'
end

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
#
group :development, :test do
  gem 'simplecov', require: false
end

group :development do
  gem 'rubocop'
  gem 'rubocop-minitest'
  gem 'rubocop-packaging'
  gem 'rubocop-performance'
  gem 'rubocop-rails'
  gem 'rubocop-rake'
  gem 'rubocop-thread_safety'
end

group :benchmark do
  gem 'benchmark'
  gem 'money-rails'
end
