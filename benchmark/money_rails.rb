# frozen_string_literal: true

# money-rails side benchmark.

require_relative 'shared'
require_relative 'suite'
require 'money-rails'
MoneyRails::Hooks.init

SIDE_NAME = 'money-rails'
TABLES = %i[money_rails_composite].freeze

def setup_schema
  ActiveRecord::Schema.define do
    create_table :money_rails_composite, force: true do |t|
      t.integer :price_cents
      t.string  :price_currency
    end
  end
end

def define_models
  Object.const_set(:MoneyRailsComposite, Class.new(ApplicationRecord) do
    self.table_name = 'money_rails_composite'
    monetize :price_cents, with_currency: :price_currency
  end)

  $money = Money.from_amount(AMOUNT, CURRENCY_CODE)
  $models = {
    'money-rails (integer cents):' => MoneyRailsComposite
  }.freeze
end

# ── Benchmark methods ──────────────────────────────────────────────

def benchmark_instantiation
  section 'Instantiation (passing Money object to setter)'
  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      x.report(label) { ITERATIONS.times { model.new(price: $money) } }
    end
  end
end

def benchmark_create_save
  section 'Create + save individual (Money through setter)'
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
  section 'Update existing record (write path without record creation overhead)'
  update_records = {}
  $models.each { |label, model| update_records[label] = model.create!(price: $money) }
  money_b = Money.from_amount(AMOUNT_ALT, CURRENCY_CODE)

  Benchmark.bm(40) do |x|
    $models.each do |label, model|
      record = model.find(update_records[label].id)
      x.report(label) do
        ITERATIONS.times { |i| record.update!(price: i.even? ? $money : money_b) }
      end
    end
  end
end

def benchmark_setter_only
  section 'Setter only (record.price = $money — isolates conversion cost)'
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
  section 'Read Money attribute from persisted record'
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
  section 'Query by raw columns (fair — both sides use column values)'
  Benchmark.bm(40) do |x|
    x.report('money-rails (integer cents, currency):') do
      ITERATIONS.times { MoneyRailsComposite.find_by(price_cents: $money.cents, price_currency: $money.currency.to_s) }
    end
  end
end

def benchmark_sql_generation
  section 'SQL generation (.to_sql)'
  Benchmark.bm(40) do |x|
    x.report('money-rails (integer cents, currency):') do
      ITERATIONS.times { MoneyRailsComposite.where(price_cents: $money.cents, price_currency: $money.currency.to_s).to_sql }
    end
  end
end

def benchmark_multi_record
  section "Query multi-record (load #{MULTI_RECORD_COUNT} records × #{MULTI_RECORD_ITERATIONS} iters — deserialization stress test)"

  ids_mr = Array.new(MULTI_RECORD_COUNT) { MoneyRailsComposite.create!(price: $money).id }
  Benchmark.bm(40) do |x|
    x.report('money-rails (integer cents):') do
      MULTI_RECORD_ITERATIONS.times { MoneyRailsComposite.where(price_cents: $money.cents, price_currency: $money.currency.to_s).to_a.each(&:price) }
    end
  end
  MoneyRailsComposite.where(id: ids_mr).delete_all
end

def benchmark_caching
  section 'Repeated access ×5000 (caching demonstration)'
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
  puts
end

def benchmark_scaling
  major_section 'Scaling: mass insert and bulk update at various batch sizes'
  puts
  puts 'size     mr insert          mr update         '

  RECORDS_SAMPLE.each do |n|
    records = Array.new(n) { MoneyRailsComposite.new(price: $money) }
    t_ins = Benchmark.measure { MoneyRailsComposite.transaction { records.each(&:save!) } }

    ids = records.map(&:id)
    bu_b = Money.from_amount(AMOUNT_ALT, CURRENCY_CODE)
    t_up = Benchmark.measure { MoneyRailsComposite.update(ids, ids.each_with_index.map { |_id, i| { price: i.even? ? $money : bu_b } }) }
    MoneyRailsComposite.delete_all

    puts format('%-8<size>s %-18<ins>s %-18<up>s', size: "#{n}:", ins: "#{t_ins.real.round(4)}s", up: "#{t_up.real.round(4)}s")
  end
end

# ── Execution ─────────────────────────────────────────────────────

run_benchmarks(
  :benchmark_instantiation,
  :benchmark_create_save,
  :benchmark_update_existing,
  :benchmark_setter_only,
  :benchmark_read_cached,
  :benchmark_query_raw_columns,
  :benchmark_sql_generation,
  :benchmark_multi_record,
  :benchmark_caching,
  :benchmark_scaling
)
