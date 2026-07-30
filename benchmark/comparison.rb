# frozen_string_literal: true

# Dispatcher — delegates to the side-specific file based on BENCH_SIDE.
#
# Run directly (preferred):
#   bundle exec ruby benchmark/minting.rb
#   bundle exec ruby benchmark/plain.rb
#   BUNDLE_GEMFILE=Gemfile.benchmark bundle exec ruby benchmark/money_rails.rb
#
# Or via BENCH_SIDE env var (backward compat):
#   BENCH_SIDE=minting     bundle exec ruby benchmark/comparison.rb
#   BENCH_SIDE=plain       bundle exec ruby benchmark/comparison.rb
#   BENCH_SIDE=money_rails BUNDLE_GEMFILE=Gemfile.benchmark bundle exec ruby benchmark/comparison.rb

ENV['RAILS_ENV'] = 'test'

require 'bundler/setup'

case ENV.fetch('BENCH_SIDE', 'minting')
when 'minting'     then load File.expand_path('minting.rb', __dir__)
when 'plain'       then load File.expand_path('plain.rb', __dir__)
when 'money_rails' then load File.expand_path('money_rails.rb', __dir__)
else raise "Unknown BENCH_SIDE=#{ENV.fetch('BENCH_SIDE')} (expected minting, plain, or money_rails)"
end
