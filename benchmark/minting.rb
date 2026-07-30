# frozen_string_literal: true

# money_attribute side benchmark (minting gem).

require_relative 'shared'
require_relative 'suite'
require 'money_attribute'

SIDE_NAME = 'money_attribute'
TABLES = %i[minting_composite minting_composite_decimal].freeze

def setup_schema
  ActiveRecord::Schema.define do
    create_table :minting_composite, force: true do |t|
      t.integer :price_amount
      t.string  :price_currency
    end
    create_table :minting_composite_decimal, force: true do |t|
      t.decimal :price_amount
      t.string  :price_currency
    end
  end
end

def define_models
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
  money_b = Mint::Money.from(AMOUNT_ALT, CURRENCY_CODE)

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
    x.report('money_attribute (integer column):') do
      ITERATIONS.times { MintingComposite.find_by(price_amount: $money.subunits, price_currency: $money.currency_code) }
    end
    x.report('money_attribute (decimal column):') do
      ITERATIONS.times { MintingCompositeDecimal.find_by(price_amount: $money.amount, price_currency: $money.currency_code) }
    end
  end
end

def benchmark_query_money_object
  section 'Query by Money object (money_attribute only — composed_of decomposition)'
  puts 'money-rails cannot decompose Money in WHERE — uses raw columns above'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') { ITERATIONS.times { MintingComposite.find_by(price: $money) } }
    x.report('money_attribute (decimal column):') { ITERATIONS.times { MintingCompositeDecimal.find_by(price: $money) } }
  end
end

def benchmark_sql_generation
  section 'SQL generation (.to_sql)'
  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') do
      ITERATIONS.times { MintingComposite.where(price_amount: $money.subunits, price_currency: $money.currency_code).to_sql }
    end
    x.report('money_attribute (decimal column):') do
      ITERATIONS.times { MintingCompositeDecimal.where(price_amount: $money.amount, price_currency: $money.currency_code).to_sql }
    end
  end
end

def benchmark_multi_record
  section "Query multi-record (load #{MULTI_RECORD_COUNT} records × #{MULTI_RECORD_ITERATIONS} iters — deserialization stress test)"

  ids_int = Array.new(MULTI_RECORD_COUNT) { MintingComposite.create!(price: $money).id }
  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') do
      MULTI_RECORD_ITERATIONS.times { MintingComposite.where(price_amount: $money.subunits, price_currency: $money.currency_code).to_a.each(&:price) }
    end
  end
  MintingComposite.where(id: ids_int).delete_all

  ids_dec = Array.new(MULTI_RECORD_COUNT) { MintingCompositeDecimal.create!(price: $money).id }
  Benchmark.bm(40) do |x|
    x.report('money_attribute (decimal column):') do
      MULTI_RECORD_ITERATIONS.times { MintingCompositeDecimal.where(price_amount: $money.amount, price_currency: $money.currency_code).to_a.each(&:price) }
    end
  end
  MintingCompositeDecimal.where(id: ids_dec).delete_all
end

def benchmark_arithmetic
  section 'Arithmetic (add two money attributes)'
  mc1 = MintingComposite.create!(price: $money)
  mc2 = MintingComposite.create!(price: $money)

  Benchmark.bm(40) do |x|
    x.report('money_attribute (integer column):') { ITERATIONS.times { (mc1.price / 3) + (mc2.price * 2) } }
  end
end

def benchmark_query_helpers
  section 'Query helpers (money_attribute)'

  records = Array.new(100) { MintingComposite.create!(price: $money) }
  dec_records = Array.new(100) { MintingCompositeDecimal.create!(price: $money) }

  money_2000 = Mint::Money.from(2000, CURRENCY_CODE)
  money_1000 = Mint::Money.from(1000, CURRENCY_CODE)
  money_9999 = Mint::Money.from(9999, CURRENCY_CODE)

  Benchmark.bm(40) do |x|
    x.report('where_amount (hash scalar):') do
      ITERATIONS.times { MintingComposite.where_amount(price: $money) }
    end

    x.report('where_amount (hash Range):') do
      ITERATIONS.times { MintingComposite.where_amount(price: $money..money_2000) }
    end

    x.report('where_amount (hash Array):') do
      ITERATIONS.times { MintingComposite.where_amount(price: [$money, Mint::Money.from(999, 'USD')]) }
    end

    x.report('where_amount (String <):') do
      ITERATIONS.times { MintingComposite.where_amount('price < ?', money_2000) }
    end

    x.report('where_amount (String AND):') do
      ITERATIONS.times { MintingComposite.where_amount('price >= ? AND price <= ?', money_1000, money_2000) }
    end

    x.report('where_amount (String NOT):') do
      ITERATIONS.times { MintingComposite.where_amount('NOT price = ?', money_9999) }
    end

    x.report('where_amount (String IS NULL):') do
      ITERATIONS.times { MintingComposite.where_amount('price IS NULL') }
    end

    x.report('where_currency:') do
      ITERATIONS.times { MintingComposite.where_currency(price: 'USD') }
    end

    x.report('order_by_amount (desc):') do
      ITERATIONS.times { MintingComposite.order_by_amount(price: :desc).load }
    end

    x.report('pluck_amount single:') do
      ITERATIONS.times { MintingComposite.pluck_amount(:price) }
    end

    x.report('pick_amount single:') do
      ITERATIONS.times { MintingComposite.pick_amount(:price) }
    end

    x.report('sum_amount:') do
      ITERATIONS.times { MintingComposite.sum_amount(:price) }
    end
  end

  MintingComposite.where(id: records.map(&:id)).delete_all
  MintingCompositeDecimal.where(id: dec_records.map(&:id)).delete_all
end

def benchmark_caching
  section 'Repeated access ×5000 (caching demonstration)'
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
  puts
end

def benchmark_format
  require 'action_view'
  include ActionView::Helpers::NumberHelper

  small = Mint::Money.from(1234.56, CURRENCY_CODE)
  large = Mint::Money.from(1_234_567_890.12, CURRENCY_CODE)
  huge  = Mint::Money.from(BigDecimal('9999999999999.99'), CURRENCY_CODE)

  small_n = 1234.56
  large_n = 1_234_567_890.12
  huge_n  = BigDecimal('9999999999999.99')

  major_section 'Format benchmark: Money.format vs number_to_currency'

  Benchmark.bm(50) do |x|
    x.report('Money.format (small default):')       { FORMAT_ITERATIONS.times { small.format } }
    x.report('number_to_currency (small default):') { FORMAT_ITERATIONS.times { number_to_currency(small_n) } }
    x.report('Money.format (large default):')       { FORMAT_ITERATIONS.times { large.format } }
    x.report('number_to_currency (large default):') { FORMAT_ITERATIONS.times { number_to_currency(large_n) } }
    x.report('Money.format (huge default):')        { FORMAT_ITERATIONS.times { huge.format } }
    x.report('number_to_currency (huge default):')  { FORMAT_ITERATIONS.times { number_to_currency(huge_n) } }
    x.report('Money.format (no symbol):')           { FORMAT_ITERATIONS.times { large.format('%<amount>f') } }
    x.report('number_to_currency (no symbol):')     { FORMAT_ITERATIONS.times { number_to_currency(large_n, unit: '') } }
    x.report('Money.format (comma dec):')           { FORMAT_ITERATIONS.times { large.format(decimal: ',', thousand: '.') } }
    x.report('number_to_currency (comma dec):')     { FORMAT_ITERATIONS.times { number_to_currency(large_n, separator: ',', delimiter: '.') } }
    x.report('Money.format (no delim):')            { FORMAT_ITERATIONS.times { large.format(thousand: false) } }
    x.report('number_to_currency (no delim):')      { FORMAT_ITERATIONS.times { number_to_currency(large_n, delimiter: '') } }
    x.report('Money.format (wide symbol):')         { FORMAT_ITERATIONS.times { large.format('%<symbol>s  %<amount>f') } }
    x.report('number_to_currency (wide symbol):')   { FORMAT_ITERATIONS.times { number_to_currency(large_n, unit: '$  ') } }
  end
  puts
end

def benchmark_scaling
  major_section 'Scaling: mass insert and bulk update at various batch sizes'
  puts
  puts 'size     int insert         int update         dec insert         dec update        '

  RECORDS_SAMPLE.each do |n|
    records_i = Array.new(n) { MintingComposite.new(price: $money) }
    t_ins_i = Benchmark.measure { MintingComposite.transaction { records_i.each(&:save!) } }

    ids_i = records_i.map(&:id)
    bu_b = Mint::Money.from(AMOUNT_ALT, CURRENCY_CODE)
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
end

# ── Execution ─────────────────────────────────────────────────────

run_benchmarks(
  :benchmark_instantiation,
  :benchmark_create_save,
  :benchmark_update_existing,
  :benchmark_setter_only,
  :benchmark_read_cached,
  :benchmark_query_raw_columns,
  :benchmark_query_money_object,
  :benchmark_sql_generation,
  :benchmark_multi_record,
  :benchmark_arithmetic,
  :benchmark_query_helpers,
  :benchmark_caching,
  :benchmark_format,
  :benchmark_scaling
)
