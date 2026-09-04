# frozen_string_literal: true

# Focused performance benchmarks for the optimization roadmap.
#
# Run with:
#   bundle exec rake bench:performance
#
# This benchmark intentionally measures money_attribute only. It isolates the
# variables that the cross-gem benchmark does not expose: query-expression
# length, repeated SQL templates, result-set size, currency cardinality, and
# index presence.

require 'benchmark'
require 'fileutils'
require 'json'
require 'rails'
require 'active_record'
require 'sqlite3'
require 'money_attribute'

DB_PATH = File.expand_path('../test/dummy/storage/test.sqlite3', __dir__)
ITERATIONS = 2_000
TABLE = :performance_offers
$results = {}

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: DB_PATH)

def create_schema
  ActiveRecord::Schema.define do
    create_table TABLE, force: true do |t|
      t.decimal :price_amount, precision: 20, scale: 4
      t.string :price_currency
    end
  end
end

create_schema

class PerformanceOffer < ActiveRecord::Base
  self.table_name = TABLE
  money_attribute :price
end

def seed_records(count, currencies: %w[USD EUR BRL])
  count.times.map do |index|
    currency = currencies[index % currencies.length]
    PerformanceOffer.create!(price: Mint::Money.from(index + 1, currency))
  end
end

def benchmark_case(benchmark, label)
  timing = benchmark.report(label) { yield }
  $results[label] = { seconds: timing.real }
end

def benchmark_string_query_scaling
  puts
  puts 'String where_amount scaling (relation construction only)'
  cases = [1, 2, 4, 8].to_h do |conditions|
    sql = Array.new(conditions, 'price >= ?').join(' AND ')
    ["#{conditions} condition(s)", [sql, *Array.new(conditions, Mint::Money.from(10, 'USD'))]]
  end

  Benchmark.bm(24) do |x|
    cases.each do |label, (sql, *values)|
      benchmark_case(x, label) { ITERATIONS.times { PerformanceOffer.where_amount(sql, *values) } }
    end
  end
end

def benchmark_cold_string_query_scaling
  puts
  puts 'Cold string where_amount scaling (plan cache cleared per call)'
  cases = [1, 2, 4, 8].to_h do |conditions|
    sql = Array.new(conditions, 'price >= ?').join(' AND ')
    ["#{conditions} condition(s)", [sql, *Array.new(conditions, Mint::Money.from(10, 'USD'))]]
  end

  Benchmark.bm(24) do |x|
    cases.each do |label, (sql, *values)|
      benchmark_case(x, label) do
        ITERATIONS.times do
          PerformanceOffer.money_attribute_query_plan_cache.clear
          PerformanceOffer.where_amount(sql, *values)
        end
      end
    end
  end
end

def legacy_parse_sql_value_specs(sql, specs, relation)
  attr_names = specs.keys.to_set
  sql.scan(/\b[a-z_]\w*\b/i).each do |word|
    next if attr_names.include?(word.downcase) || MoneyAttribute::AmountCondition::ALLOWED_KEYWORDS.include?(word.downcase)

    raise ArgumentError, "'#{word}' is not a money attribute on #{relation.klass.name}"
  end

  pattern = /\b(#{specs.keys.map { |name| Regexp.escape(name) }.join('|')})\b/i
  positions = []
  offset = 0
  while (index = sql.index('?', offset))
    positions << index
    offset = index + 1
  end

  positions.map do |position|
    matched = sql[0...position].scan(pattern).flatten.compact
    raise ArgumentError, "No money attribute found before '?' in: #{sql.inspect}" if matched.empty?

    specs[matched.last.downcase]
  end
end

def benchmark_parser_algorithm
  puts
  puts 'Parser algorithm comparison (cache-independent)'
  relation = PerformanceOffer.all
  specs = PerformanceOffer.money_attribute_specs

  Benchmark.bm(32) do |x|
    [1, 2, 4, 8, 16, 32].each do |conditions|
      sql = Array.new(conditions, 'price >= ?').join(' AND ')
      x.report("single-pass (#{conditions} conditions)") do
        ITERATIONS.times { relation.send(:parse_sql_value_specs, sql, specs) }
      end
      x.report("legacy multi-scan (#{conditions} conditions)") do
        ITERATIONS.times { legacy_parse_sql_value_specs(sql, specs, relation) }
      end
    end
  end
end

def benchmark_repeated_query_template
  puts
  puts 'Repeated versus varying SQL templates'
  value = Mint::Money.from(10, 'USD')

  Benchmark.bm(32) do |x|
    benchmark_case(x, 'same SQL template') do
      ITERATIONS.times { PerformanceOffer.where_amount('price >= ? AND price <= ?', value, value) }
    end
    benchmark_case(x, 'varying SQL whitespace') do
      ITERATIONS.times do |index|
        sql = index.even? ? 'price >= ? AND price <= ?' : 'price >= ?  AND price <= ?'
        PerformanceOffer.where_amount(sql, value, value)
      end
    end
    benchmark_case(x, 'many SQL templates') do
      ITERATIONS.times do |index|
        sql = "price#{' ' * (index % 100 + 1)}>= ?"
        PerformanceOffer.where_amount(sql, value)
      end
    end
  end
end

def benchmark_pluck_scaling
  puts
  puts 'Composite pluck reconstruction scaling'
  Benchmark.bm(32) do |x|
    [10, 100, 1_000].each do |count|
      relation = PerformanceOffer.where(id: $single_currency_ids.first(count))
      benchmark_case(x, "pluck_amount (#{count} rows)") { ITERATIONS.times { relation.pluck_amount(:price) } }
    end
  end
end

def benchmark_pluck_currency_cardinality
  puts
  puts 'Composite pluck currency cardinality'
  same_currency = PerformanceOffer.where(id: $single_currency_ids)
  mixed_currency = PerformanceOffer.where(id: $mixed_currency_ids)

  Benchmark.bm(32) do |x|
    benchmark_case(x, '1,000 rows, one currency') { ITERATIONS.times { same_currency.pluck_amount(:price) } }
    benchmark_case(x, '1,000 rows, three currencies') { ITERATIONS.times { mixed_currency.pluck_amount(:price) } }
  end
end

def allocated_objects
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
end

def benchmark_pluck_allocations
  puts
  puts 'Composite pluck allocations (one call)'
  relation = PerformanceOffer.where(id: $mixed_currency_ids)
  GC.start
  GC.disable
  allocations = allocated_objects { relation.pluck_amount(:price) }
  $results['pluck_amount allocations (1,000 rows)'] = { objects: allocations }
  puts format('  %<value>d objects for 1,000 reconstructed values', value: allocations)
ensure
  GC.enable
end

def benchmark_index_effect
  puts
  puts 'Indexed versus unindexed currency + amount query'
  relation = PerformanceOffer.where_currency(price: 'USD').order_by_amount(price: :desc).limit(100)

  Benchmark.bm(32) do |x|
    benchmark_case(x, 'without composite index') { ITERATIONS.times { relation.load; relation.reset } }
    PerformanceOffer.connection.add_index(TABLE, %i[price_currency price_amount], name: 'performance_price_lookup')
    benchmark_case(x, 'with composite index') { ITERATIONS.times { relation.load; relation.reset } }
  ensure
    PerformanceOffer.connection.remove_index(TABLE, name: 'performance_price_lookup') if
      PerformanceOffer.connection.index_name_exists?(TABLE, 'performance_price_lookup')
  end
end

$single_currency_ids = seed_records(1_000, currencies: ['USD']).map(&:id)
$mixed_currency_ids = seed_records(1_000).map(&:id)

begin
  benchmark_string_query_scaling
  benchmark_cold_string_query_scaling
  benchmark_parser_algorithm
  benchmark_repeated_query_template
  benchmark_pluck_scaling
  benchmark_pluck_currency_cardinality
  benchmark_pluck_allocations
  benchmark_index_effect
ensure
  PerformanceOffer.connection.drop_table(TABLE, if_exists: true)
end

output = ENV.fetch('PERFORMANCE_OUTPUT', 'tmp/performance.json')
FileUtils.mkdir_p(File.dirname(output))
File.write(output, JSON.pretty_generate({ ruby: RUBY_VERSION, rails: Rails::VERSION::STRING, results: $results }))
puts "\nMachine-readable results written to #{output}"
