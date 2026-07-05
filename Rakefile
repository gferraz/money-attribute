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
task test_db_migrate: :environment do
  Dir.chdir('test/dummy') do # rubocop:disable ThreadSafety/DirChdir
    sh({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'db:migrate')
  end
end

desc 'Run tests (migrates test DB first)'
task test: %i[test_db_migrate test_run]

desc 'Run money_attribute vs money-rails benchmark'
task bench: :environment do
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
  sh({ 'RAILS_ENV' => 'test', 'BENCH_SIDE' => 'money_rails' },
     'bundle', 'exec', 'ruby', 'benchmark/comparison.rb')
end

desc 'Generate consolidated benchmark report (markdown)'
task bench_report: :environment do
  ruby 'benchmark/report.rb'
end
