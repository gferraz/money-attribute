# frozen_string_literal: true

# Competitive benchmark: money_attribute vs money-rails
# Run with: bundle exec ruby benchmark/comparison.rb
#
# Each side runs in a separate process via BENCH_SIDE env var
# so the minting and money gem stacks never collide:
#   BENCH_SIDE=minting   → money_attribute models (minting gem)
#   BENCH_SIDE=money_rails → money-rails models (money gem)

ENV['RAILS_ENV'] = 'test'

require 'bundler/setup'
require 'benchmark'

BENCH_SIDE = ENV.fetch('BENCH_SIDE', 'minting')

case BENCH_SIDE
when 'minting'
  require 'rails'
  require 'active_record'
  require 'sqlite3'
  require 'money_attribute'

  db_path = File.expand_path('../test/dummy/storage/test.sqlite3', __dir__)
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: db_path
  )

  # :nodoc:
  class ApplicationRecord < ActiveRecord::Base
    primary_abstract_class
  end
when 'money_rails'
  require 'rails'
  require 'active_record'
  require 'sqlite3'

  db_path = File.expand_path('../test/dummy/storage/test.sqlite3', __dir__)
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: db_path
  )

  # :nodoc:
  class ApplicationRecord < ActiveRecord::Base
    primary_abstract_class
  end

  require 'money-rails'
  MoneyRails::Hooks.init
else
  raise "Unknown BENCH_SIDE=#{BENCH_SIDE} (expected minting or money_rails)"
end

# ── Shared setup ────────────────────────────────────────────────

AMOUNT = BigDecimal('1234.56')
CURRENCY_CODE = 'USD'
NUM_RECORDS = 1_000
ITERATIONS = 5_000

# ── Tables ──────────────────────────────────────────────────────

TABLES =
  case BENCH_SIDE
  when 'minting'
    %i[minting_composite minting_composite_decimal].freeze
  when 'money_rails'
    %i[money_rails_composite].freeze
  end

# ── Schema setup ───────────────────────────────────────────

def setup_schema
  ActiveRecord::Schema.define do
    case BENCH_SIDE
    when 'minting'
      create_table :minting_composite, force: true do |t|
        t.integer :price_amount
        t.string  :price_currency
      end
      create_table :minting_composite_decimal, force: true do |t|
        t.decimal :price_amount
        t.string  :price_currency
      end
    when 'money_rails'
      create_table :money_rails_composite, force: true do |t|
        t.integer :price_cents
        t.string  :price_currency
      end
    end
  end
end

# ── Model definitions ───────────────────────────────────────

def define_models
  case BENCH_SIDE
  when 'minting'
    Object.const_set(:MintingComposite, Class.new(ApplicationRecord) do
      self.table_name = 'minting_composite'
      money_attribute :price
    end)
    Object.const_set(:MintingCompositeDecimal, Class.new(ApplicationRecord) do
      self.table_name = 'minting_composite_decimal'
      money_attribute :price
    end)

    $money = Mint::Money.from(AMOUNT, CURRENCY_CODE)
    $models = {
      'money_attribute (integer column):' => MintingComposite,
      'money_attribute (decimal column):' => MintingCompositeDecimal
    }.freeze

  when 'money_rails'
    Object.const_set(:MoneyRailsComposite, Class.new(ApplicationRecord) do
      self.table_name = 'money_rails_composite'
      monetize :price_cents, with_currency: :price_currency
    end)

    $money = Money.from_amount(AMOUNT, CURRENCY_CODE)
    $models = {
      'money-rails (integer cents):' => MoneyRailsComposite
    }.freeze
  end
end

def print_header
  header = "Benchmark: #{BENCH_SIDE == 'minting' ? 'money_attribute' : 'money-rails'}"

  puts '=' * 80
  puts header
  puts "Ruby #{RUBY_VERSION}, Rails #{Gem.loaded_specs['rails']&.version || '?'}, SQLite3"
  puts "#{ITERATIONS} iterations per test, #{NUM_RECORDS} records for mass insert"
  puts '=' * 80
  puts
end

# ── Benchmark methods ──────────────────────────────────────

def benchmark_instantiation
  puts '-' * 60
  puts 'Instantiation (passing Money object to setter)'
  puts '-' * 60
  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      x.report(label) do
        ITERATIONS.times { model.new(price: $money) }
      end
    end
  end
end

def benchmark_create_save
  puts '-' * 60
  puts 'Create + save individual (Money through setter)'
  puts '-' * 60
  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      x.report(label) do
        ITERATIONS.times { model.create!(price: $money) }
        model.delete_all
      end
    end
  end
end

def benchmark_update_existing
  puts '-' * 60
  puts 'Update existing record (write path without record creation overhead)'
  puts '-' * 60

  update_records = {}
  $models.each { |label, model| update_records[label] = model.create!(price: $money) }

  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      record = model.find(update_records[label].id)
      money_b = BENCH_SIDE == 'minting' ? Mint::Money.from(AMOUNT + 1, CURRENCY_CODE) : Money.from_amount(AMOUNT + 1, CURRENCY_CODE)

      x.report(label) do
        ITERATIONS.times { |i| record.update!(price: i.even? ? $money : money_b) }
      end
    end
  end
end

def benchmark_setter_only
  puts '-' * 60
  puts 'Setter only (record.price = $money — isolates conversion cost)'
  puts '-' * 60

  setter_records = {}
  $models.each { |label, model| setter_records[label] = model.create!(price: $money) }

  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      record = model.find(setter_records[label].id)
      x.report(label) { ITERATIONS.times { record.price = $money } }
    end
  end
end

def benchmark_read_cached
  puts '-' * 60
  puts 'Read Money attribute from persisted record'
  puts '-' * 60

  records = {}
  $models.each { |label, model| records[label] = model.create!(price: $money) }

  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      record = model.find(records[label].id)
      x.report(label) { ITERATIONS.times { record.price } }
    end
  end
end

def benchmark_query_raw_columns
  puts '-' * 60
  puts 'Query by raw columns (fair — both sides use column values)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    case BENCH_SIDE
    when 'minting'
      x.report('money_attribute (integer column):') do
        ITERATIONS.times { MintingComposite.find_by(price_amount: $money.subunits, price_currency: $money.currency_code) }
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times { MintingCompositeDecimal.find_by(price_amount: $money.amount, price_currency: $money.currency_code) }
      end
    when 'money_rails'
      x.report('money-rails (integer cents, currency):') do
        ITERATIONS.times { MoneyRailsComposite.find_by(price_cents: $money.cents, price_currency: $money.currency.to_s) }
      end
    end
  end
end

def benchmark_query_money_object
  return unless BENCH_SIDE == 'minting'

  puts '-' * 60
  puts 'Query by Money object (money_attribute only — composed_of decomposition)'
  puts 'money-rails cannot decompose Money in WHERE — uses raw columns above'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') { ITERATIONS.times { MintingComposite.find_by(price: $money) } }
    x.report('money_attribute (decimal column):') { ITERATIONS.times { MintingCompositeDecimal.find_by(price: $money) } }
  end
end

def benchmark_sql_generation
  puts '-' * 60
  puts 'SQL generation (.to_sql)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    case BENCH_SIDE
    when 'minting'
      x.report('money_attribute (integer column):') do
        ITERATIONS.times { MintingComposite.where(price_amount: $money.subunits, price_currency: $money.currency_code).to_sql }
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times { MintingCompositeDecimal.where(price_amount: $money.amount, price_currency: $money.currency_code).to_sql }
      end
    when 'money_rails'
      x.report('money-rails (integer cents, currency):') do
        ITERATIONS.times { MoneyRailsComposite.where(price_cents: $money.cents, price_currency: $money.currency.to_s).to_sql }
      end
    end
  end
end

def benchmark_multi_record
  puts '-' * 60
  puts 'Query multi-record (load 100 records × 1000 iters — deserialization stress test)'
  puts '-' * 60

  case BENCH_SIDE
  when 'minting'
    ids_int = Array.new(100) { MintingComposite.create!(price: $money).id }
    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):') do
        1000.times { MintingComposite.where(price_amount: $money.subunits, price_currency: $money.currency_code).to_a.each(&:price) }
      end
    end
    MintingComposite.where(id: ids_int).delete_all

    ids_dec = Array.new(100) { MintingCompositeDecimal.create!(price: $money).id }
    Benchmark.bm(40) do |x|
      x.report('money_attribute (decimal column):') do
        1000.times { MintingCompositeDecimal.where(price_amount: $money.amount, price_currency: $money.currency_code).to_a.each(&:price) }
      end
    end
    MintingCompositeDecimal.where(id: ids_dec).delete_all

  when 'money_rails'
    ids_mr = Array.new(100) { MoneyRailsComposite.create!(price: $money).id }
    Benchmark.bm(40) do |x|
      x.report('money-rails (integer cents):') do
        1000.times { MoneyRailsComposite.where(price_cents: $money.cents, price_currency: $money.currency.to_s).to_a.each(&:price) }
      end
    end
    MoneyRailsComposite.where(id: ids_mr).delete_all
  end
end

def benchmark_arithmetic
  return unless BENCH_SIDE == 'minting'

  puts '-' * 60
  puts 'Arithmetic (add two money attributes)'
  puts '-' * 60

  mc1 = MintingComposite.create!(price: $money)
  mc2 = MintingComposite.create!(price: $money)

  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') { ITERATIONS.times { (mc1.price / 3) + (mc2.price * 2) } }
  end
end

def benchmark_caching
  puts '-' * 60
  puts 'Repeated access ×1000 (caching demonstration)'
  puts '-' * 60

  if BENCH_SIDE == 'minting'
    puts 'composed_of used by Mint returns zero-allocation cached objects.'
    puts

    mcc = MintingComposite.create!(price: $money)
    mcc_d = MintingCompositeDecimal.create!(price: $money)

    puts "money_attribute composite int same object? #{mcc.price.equal?(mcc.price)}"
    puts "money_attribute composite dec same object? #{mcc_d.price.equal?(mcc_d.price)}"
    puts

    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):') { ITERATIONS.times { mcc.price } }
      x.report('money_attribute (decimal column):') { ITERATIONS.times { mcc_d.price } }
    end

    int_alloc = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mcc.price }
    int_alloc = GC.stat(:total_allocated_objects) - int_alloc

    dec_alloc = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mcc_d.price }
    dec_alloc = GC.stat(:total_allocated_objects) - dec_alloc

    puts
    puts format('%-40<label>s %<value>10s', label: 'money_attribute (integer column) allocated:', value: int_alloc.to_s)
    puts format('%-40<label>s %<value>10s', label: 'money_attribute (decimal column) allocated:', value: dec_alloc.to_s)
  else
    puts 'Money-rails re-runs currency lookups and comparisons on every read.'
    puts

    mrcc = MoneyRailsComposite.create!(price: $money)
    puts "money-rails composite int same object? #{mrcc.price.equal?(mrcc.price)}"
    puts

    Benchmark.bm(40) { |x| x.report('money-rails (integer cents):') { ITERATIONS.times { mrcc.price } } }

    mr_alloc = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mrcc.price }
    mr_alloc = GC.stat(:total_allocated_objects) - mr_alloc

    puts
    puts format('%-40<label>s %<value>10s', label: 'money-rails (integer cents) allocated:', value: mr_alloc.to_s)
  end
  puts
end

def benchmark_scaling
  puts
  puts '─' * 60
  puts 'Scaling: mass insert and bulk update at various batch sizes'
  puts '─' * 60

  if BENCH_SIDE == 'minting'
    puts
    puts 'size     int insert         int update         dec insert         dec update        '

    [100, 500, 1000, 2000].each do |n|
      records_i = Array.new(n) { MintingComposite.new(price: $money) }
      t_ins_i = Benchmark.measure { MintingComposite.transaction { records_i.each(&:save!) } }

      ids_i = records_i.map(&:id)
      bu_b = Mint::Money.from(AMOUNT + 1, CURRENCY_CODE)
      t_up_i = Benchmark.measure { MintingComposite.update(ids_i, ids_i.each_with_index.map { |_id, i| { price: i.even? ? $money : bu_b } }) }
      MintingComposite.delete_all

      records_d = Array.new(n) { MintingCompositeDecimal.new(price: $money) }
      t_ins_d = Benchmark.measure { MintingCompositeDecimal.transaction { records_d.each(&:save!) } }

      ids_d = records_d.map(&:id)
      t_up_d = Benchmark.measure { MintingCompositeDecimal.update(ids_d, ids_d.each_with_index.map { |_id, i| { price: i.even? ? $money : bu_b } }) }
      MintingCompositeDecimal.delete_all

      puts format('%-8<size>s %-18<int_ins>s %-18<int_up>s %-18<dec_ins>s %-18<dec_up>s',
                  size: "#{n}:", int_ins: "#{t_ins_i.real.round(4)}s", int_up: "#{t_up_i.real.round(4)}s",
                  dec_ins: "#{t_ins_d.real.round(4)}s", dec_up: "#{t_up_d.real.round(4)}s")
    end

  else
    puts
    puts 'size     mr insert          mr update         '

    [100, 500, 1000, 2000].each do |n|
      records = Array.new(n) { MoneyRailsComposite.new(price: $money) }
      t_ins = Benchmark.measure { MoneyRailsComposite.transaction { records.each(&:save!) } }

      ids = records.map(&:id)
      bu_b = Money.from_amount(AMOUNT + 1, CURRENCY_CODE)
      t_up = Benchmark.measure { MoneyRailsComposite.update(ids, ids.each_with_index.map { |_id, i| { price: i.even? ? $money : bu_b } }) }
      MoneyRailsComposite.delete_all

      puts format('%-8<size>s %-18<ins>s %-18<up>s', size: "#{n}:", ins: "#{t_ins.real.round(4)}s", up: "#{t_up.real.round(4)}s")
    end
  end
end

def cleanup_tables
  ActiveRecord::Schema.define do
    TABLES.each { |t| drop_table t, force: true }
  end
  puts
  puts 'Done. Temporary tables dropped.'
end

# ── Execution ─────────────────────────────────────────────────────

setup_schema
define_models
print_header

begin
  benchmark_instantiation
  benchmark_create_save
  benchmark_update_existing
  benchmark_setter_only
  benchmark_read_cached
  benchmark_query_raw_columns
  benchmark_query_money_object
  benchmark_sql_generation
  benchmark_multi_record
  benchmark_arithmetic
  benchmark_caching
  benchmark_scaling
rescue StandardError => e
  puts "\nError: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  raise
ensure
  cleanup_tables
end
