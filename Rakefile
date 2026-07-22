# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'

task default: :test_run

desc 'Run tests'
Rake::TestTask.new(:test_run) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.ruby_opts << '-rtest_helper.rb'
end

desc 'Migrate test database'
task :test_db_migrate do
  sh({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'db:migrate', chdir: 'test/dummy')
end

desc 'Run tests (migrates test DB first)'
task test: %i[test_db_migrate test_run]

desc 'Run money_attribute vs money-rails benchmark'
task bench: :test_db_migrate do
  puts
  puts '=' * 80
  puts 'money_attribute (minting gem)'
  puts '=' * 80
  sh({ 'RAILS_ENV' => 'test', 'BENCH_SIDE' => 'minting' },
     'bundle', 'exec', 'ruby', 'benchmark/comparison.rb')

  puts
  puts '=' * 80
  puts 'money-rails (money gem)'
  puts '=' * 80
  sh({ 'RAILS_ENV' => 'test', 'BENCH_SIDE' => 'money_rails',
       'BUNDLE_GEMFILE' => 'Gemfile.benchmark' },
     'bundle', 'exec', 'ruby', 'benchmark/comparison.rb')
end

desc 'Generate consolidated benchmark report (markdown)'
task 'bench:report' do
  ruby 'benchmark/report.rb'
end
