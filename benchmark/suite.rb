# frozen_string_literal: true

# Shared benchmark helpers used by all three side files.

require 'benchmark'

def section(title)
  puts '-' * 60
  puts title
  puts '-' * 60
end

def major_section(title)
  puts
  puts '─' * 60
  puts title
  puts '─' * 60
end

def cleanup_tables
  ActiveRecord::Schema.define do
    TABLES.each { |t| drop_table t, force: true }
  end
  puts
  puts 'Done. Temporary tables dropped.'
end

def print_header(side_name)
  puts '=' * 80
  puts "Benchmark: #{side_name}"
  puts "Ruby #{RUBY_VERSION}, Rails #{Gem.loaded_specs['rails']&.version || '?'}, SQLite3"
  puts "#{ITERATIONS} iterations per test, #{NUM_RECORDS} records for mass insert"
  puts '=' * 80
  puts
end

def run_benchmarks(*methods)
  setup_schema
  define_models
  print_header(SIDE_NAME)

  begin
    methods.each { |m| send(m) }
  rescue StandardError => e
    puts "\nError: #{e.class}: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    raise
  ensure
    cleanup_tables
  end
end
