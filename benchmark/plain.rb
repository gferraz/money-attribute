# frozen_string_literal: true

# Plain Rails side benchmark (raw columns, no monetization).

require_relative 'shared'
require_relative 'suite'

SIDE_NAME = 'plain Rails'
TABLES = %i[plain_composites plain_composites_dec].freeze

def setup_schema
  ActiveRecord::Schema.define do
    create_table :plain_composites, force: true do |t|
      t.integer :price_amount
      t.string  :price_currency
    end
    create_table :plain_composites_dec, force: true do |t|
      t.decimal :price_amount
      t.string  :price_currency
    end
  end
end

def define_models
  Object.const_set(:PlainComposite, Class.new(ApplicationRecord) do
    self.table_name = 'plain_composites'
  end)
  Object.const_set(:PlainCompositeDec, Class.new(ApplicationRecord) do
    self.table_name = 'plain_composites_dec'
  end)
end

# ── Benchmark methods ──────────────────────────────────────────────

def benchmark_instantiation
  section 'Instantiation (passing raw column values)'
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') do
      ITERATIONS.times { PlainComposite.new(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }
    end
    x.report('plain Rails (decimal column):') do
      ITERATIONS.times { PlainCompositeDec.new(price_amount: AMOUNT, price_currency: CURRENCY_CODE) }
    end
  end
end

def benchmark_create_save
  section 'Create + save individual (raw column values)'
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') do
      ITERATIONS.times { PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }
      PlainComposite.delete_all
    end
    x.report('plain Rails (decimal column):') do
      ITERATIONS.times { PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE) }
      PlainCompositeDec.delete_all
    end
  end
end

def benchmark_update_existing
  section 'Update existing record (raw column values)'
  Benchmark.bm(40) do |x|
    rec_i = PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE)
    x.report('plain Rails (integer column):') do
      ITERATIONS.times { |i| rec_i.update!(price_amount: i.even? ? AMOUNT_SUBUNITS : ALT_SUBUNITS, price_currency: CURRENCY_CODE) }
    end
    PlainComposite.delete_all

    rec_d = PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE)
    x.report('plain Rails (decimal column):') do
      ITERATIONS.times { |i| rec_d.update!(price_amount: i.even? ? AMOUNT : AMOUNT_ALT, price_currency: CURRENCY_CODE) }
    end
    PlainCompositeDec.delete_all
  end
end

def benchmark_setter_only
  section 'Setter only (record.price_amount = value — raw column)'
  Benchmark.bm(40) do |x|
    rec_i = PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE)
    x.report('plain Rails (integer column):') { ITERATIONS.times { rec_i.price_amount = AMOUNT_SUBUNITS } }
    PlainComposite.delete_all

    rec_d = PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE)
    x.report('plain Rails (decimal column):') { ITERATIONS.times { rec_d.price_amount = AMOUNT } }
    PlainCompositeDec.delete_all
  end
end

def benchmark_read_cached
  section 'Read raw column from persisted record'

  rec_i = PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE)
  rec_i.reload
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') { ITERATIONS.times { rec_i.price_amount } }
  end

  rec_d = PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE)
  rec_d.reload
  Benchmark.bm(40) do |x|
    x.report('plain Rails (decimal column):') { ITERATIONS.times { rec_d.price_amount } }
  end
end

def benchmark_query_raw_columns
  section 'Query by raw columns (fair — both sides use column values)'
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') do
      ITERATIONS.times { PlainComposite.find_by(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }
    end
    x.report('plain Rails (decimal column):') do
      ITERATIONS.times { PlainCompositeDec.find_by(price_amount: AMOUNT, price_currency: CURRENCY_CODE) }
    end
  end
end

def benchmark_sql_generation
  section 'SQL generation (.to_sql)'
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') do
      ITERATIONS.times { PlainComposite.where(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE).to_sql }
    end
    x.report('plain Rails (decimal column):') do
      ITERATIONS.times { PlainCompositeDec.where(price_amount: AMOUNT, price_currency: CURRENCY_CODE).to_sql }
    end
  end
end

def benchmark_multi_record
  section "Query multi-record (load #{MULTI_RECORD_COUNT} records × #{MULTI_RECORD_ITERATIONS} iters — plain attribute access)"

  ids_int = Array.new(MULTI_RECORD_COUNT) { PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE).id }
  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') do
      MULTI_RECORD_ITERATIONS.times { PlainComposite.where(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE).to_a.each { |r| r.price_amount } }
    end
  end
  PlainComposite.where(id: ids_int).delete_all

  ids_dec = Array.new(MULTI_RECORD_COUNT) { PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE).id }
  Benchmark.bm(40) do |x|
    x.report('plain Rails (decimal column):') do
      MULTI_RECORD_ITERATIONS.times { PlainCompositeDec.where(price_amount: AMOUNT, price_currency: CURRENCY_CODE).to_a.each { |r| r.price_amount } }
    end
  end
  PlainCompositeDec.where(id: ids_dec).delete_all
end

def benchmark_query_helpers
  section 'Query helpers (plain Rails — raw column equivalents)'

  records = Array.new(100) { PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }

  raw_2000 = 200_000
  raw_1000 = 100_000
  raw_9999 = 999_900
  raw_999  = 99_900

  Benchmark.bm(40) do |x|
    x.report('where_amount (hash scalar):') do
      ITERATIONS.times { PlainComposite.where(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }
    end

    x.report('where_amount (hash Range):') do
      ITERATIONS.times { PlainComposite.where(price_amount: AMOUNT_SUBUNITS..raw_2000, price_currency: CURRENCY_CODE) }
    end

    x.report('where_amount (hash Array):') do
      ITERATIONS.times { PlainComposite.where(price_amount: [AMOUNT_SUBUNITS, raw_999], price_currency: CURRENCY_CODE) }
    end

    x.report('where_amount (String <):') do
      ITERATIONS.times { PlainComposite.where('price_amount < ?', raw_2000) }
    end

    x.report('where_amount (String AND):') do
      ITERATIONS.times { PlainComposite.where('price_amount >= ? AND price_amount <= ?', raw_1000, raw_2000) }
    end

    x.report('where_amount (String NOT):') do
      ITERATIONS.times { PlainComposite.where('NOT price_amount = ?', raw_9999) }
    end

    x.report('where_amount (String IS NULL):') do
      ITERATIONS.times { PlainComposite.where('price_amount IS NULL') }
    end

    x.report('where_currency:') do
      ITERATIONS.times { PlainComposite.where(price_currency: 'USD') }
    end

    x.report('order_by_amount (desc):') do
      ITERATIONS.times { PlainComposite.order(price_amount: :desc).load }
    end

    x.report('pluck_amount single:') do
      ITERATIONS.times { PlainComposite.pluck(:price_amount) }
    end

    x.report('pick_amount single:') do
      ITERATIONS.times { PlainComposite.pick(:price_amount) }
    end

    x.report('sum_amount:') do
      ITERATIONS.times { PlainComposite.group(:price_currency).sum(:price_amount) }
    end
  end

  PlainComposite.where(id: records.map(&:id)).delete_all
end

def benchmark_caching
  section 'Repeated access ×5000 (caching demonstration)'
  puts 'Plain ActiveRecord reads raw values from attributes hash.'
  puts

  rec_i = PlainComposite.create!(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE)
  rec_i.reload
  rec_d = PlainCompositeDec.create!(price_amount: AMOUNT, price_currency: CURRENCY_CODE)
  rec_d.reload

  puts "plain Rails (int) same object? #{rec_i.price_amount.equal?(rec_i.price_amount)}"
  puts "plain Rails (dec) same object? #{rec_d.price_amount.equal?(rec_d.price_amount)}"
  puts

  Benchmark.bm(40) do |x|
    x.report('plain Rails (integer column):') { ITERATIONS.times { rec_i.price_amount } }
    x.report('plain Rails (decimal column):') { ITERATIONS.times { rec_d.price_amount } }
  end

  int_alloc = GC.stat(:total_allocated_objects)
  ITERATIONS.times { rec_i.price_amount }
  int_alloc = GC.stat(:total_allocated_objects) - int_alloc

  dec_alloc = GC.stat(:total_allocated_objects)
  ITERATIONS.times { rec_d.price_amount }
  dec_alloc = GC.stat(:total_allocated_objects) - dec_alloc

  puts
  puts format('%-40<label>s %<value>10s', label: 'plain Rails (integer column) allocated:', value: int_alloc.to_s)
  puts format('%-40<label>s %<value>10s', label: 'plain Rails (decimal column) allocated:', value: dec_alloc.to_s)
  puts
end

def benchmark_scaling
  major_section 'Scaling: mass insert and bulk update at various batch sizes'
  puts
  puts 'size     int insert         int update         dec insert         dec update        '

  RECORDS_SAMPLE.each do |n|
    records_i = Array.new(n) { PlainComposite.new(price_amount: AMOUNT_SUBUNITS, price_currency: CURRENCY_CODE) }
    t_ins_i = Benchmark.measure { PlainComposite.transaction { records_i.each(&:save!) } }

    ids_i = records_i.map(&:id)
    t_up_i = Benchmark.measure { PlainComposite.update(ids_i, ids_i.each_with_index.map { |_id, i| { price_amount: i.even? ? AMOUNT_SUBUNITS : ALT_SUBUNITS, price_currency: CURRENCY_CODE } }) }
    PlainComposite.delete_all

    records_d = Array.new(n) { PlainCompositeDec.new(price_amount: AMOUNT, price_currency: CURRENCY_CODE) }
    t_ins_d = Benchmark.measure { PlainCompositeDec.transaction { records_d.each(&:save!) } }

    ids_d = records_d.map(&:id)
    t_up_d = Benchmark.measure { PlainCompositeDec.update(ids_d, ids_d.each_with_index.map { |_id, i| { price_amount: i.even? ? AMOUNT : AMOUNT_ALT, price_currency: CURRENCY_CODE } }) }
    PlainCompositeDec.delete_all

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
  :benchmark_sql_generation,
  :benchmark_multi_record,
  :benchmark_query_helpers,
  :benchmark_caching,
  :benchmark_scaling
)
