# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake/testtask'

task default: :test

Rake::TestTask.new(:test_run) do |t|
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
  t.ruby_opts << '-rtest_helper.rb'
end

desc 'Migrate test database'
task :test_db_migrate do
  Dir.chdir('test/dummy') do
    sh({ 'RAILS_ENV' => 'test' }, 'bin/rails', 'db:migrate')
  end
end

desc 'Run tests (migrates test DB first)'
task test: [:test_db_migrate, :test_run]
