# frozen_string_literal: true

# rubocop:disable Style/FormatStringToken, Metrics/BlockLength
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

begin
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

  # ── Models ───────────────────────────────────────────────────────

  case BENCH_SIDE
  when 'minting'
    MintingComposite = Class.new(ApplicationRecord) do
      self.table_name = 'minting_composite'
      money_attribute :price
    end
    MintingCompositeDecimal = Class.new(ApplicationRecord) do
      self.table_name = 'minting_composite_decimal'
      money_attribute :price
    end

    MONEY = Mint::Money.from(AMOUNT, CURRENCY_CODE)

    MODELS = {
      'money_attribute (integer column):' => MintingComposite,
      'money_attribute (decimal column):' => MintingCompositeDecimal
    }.freeze

  when 'money_rails'
    MoneyRailsComposite = Class.new(ApplicationRecord) do
      self.table_name = 'money_rails_composite'
      monetize :price_cents, with_currency: :price_currency
    end

    MONEY = Money.from_amount(AMOUNT, CURRENCY_CODE)

    MODELS = {
      'money-rails (integer cents):' => MoneyRailsComposite
    }.freeze
  end

  # NOTE: money-rails is not benchmarked with decimal columns because it
  # natively stores amounts as cents (integer). It has no built-in support
  # for decimal amount columns.

  HEADER = "Benchmark: #{BENCH_SIDE == 'minting' ? 'money_attribute' : 'money-rails'}".freeze

  puts '=' * 80
  puts HEADER
  puts "Ruby #{RUBY_VERSION}, Rails #{Gem.loaded_specs['rails']&.version || '?'}, SQLite3"
  puts "#{ITERATIONS} iterations per test, #{NUM_RECORDS} records for mass insert"
  puts '=' * 80
  puts

  # ── 1. Instantiation ──────────────────────────────────────────

  puts '-' * 60
  puts 'Instantiation (passing Money object to setter)'
  puts '-' * 60
  Benchmark.bm(40) do |x|
    MODELS.each do |label, model|
      x.report(label) do
        ITERATIONS.times { model.new(price: MONEY) }
      end
    end
  end

  # ── 2. Create + persist ───────────────────────────────────────

  puts '-' * 60
  puts 'Create + save individual (Money through setter)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    MODELS.each do |label, model|
      x.report(label) do
        ITERATIONS.times { model.create!(price: MONEY) }
        model.delete_all
      end
    end
  end

  # ── 2b. Update existing record ──────────────────────────────────

  puts '-' * 60
  puts 'Update existing record (write path without record creation overhead)'
  puts '-' * 60

  update_records = {}
  MODELS.each do |label, model|
    update_records[label] = model.create!(price: MONEY)
  end

  Benchmark.bm(40) do |x|
    MODELS.each do |label, model|
      record = model.find(update_records[label].id)
      money_b = Mint::Money.from(AMOUNT + 1, CURRENCY_CODE) if BENCH_SIDE == 'minting'
      money_b = Money.from_amount(AMOUNT + 1, CURRENCY_CODE) if BENCH_SIDE == 'money_rails'

      x.report(label) do
        ITERATIONS.times do |i|
          record.update!(price: i.even? ? MONEY : money_b)
        end
      end
    end
  end

  # ── 2c. Setter only (no DB write) ───────────────────────────────

  puts '-' * 60
  puts 'Setter only (record.price = MONEY — isolates conversion cost)'
  puts '-' * 60

  setter_records = {}
  MODELS.each do |label, model|
    setter_records[label] = model.create!(price: MONEY)
  end

  Benchmark.bm(40) do |x|
    MODELS.each do |label, model|
      record = model.find(setter_records[label].id)
      x.report(label) do
        ITERATIONS.times { record.price = MONEY }
      end
    end
  end

  # ── 3. Read after reload ──────────────────────────────────────

  puts '-' * 60
  puts 'Read Money attribute from persisted record'
  puts '-' * 60

  records = {}
  MODELS.each do |label, model|
    records[label] = model.create!(price: MONEY)
  end

  Benchmark.bm(40) do |x|
    MODELS.each do |label, model|
      record = model.find(records[label].id)
      x.report(label) do
        ITERATIONS.times { record.price }
      end
    end
  end

  # ── 4. Query: raw columns (fair comparison) ──────────────────

  puts '-' * 60
  puts 'Query by raw columns (fair — both sides use column values)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    case BENCH_SIDE
    when 'minting'
      x.report('money_attribute (integer column):') do
        ITERATIONS.times do
          MintingComposite.find_by(
            price_amount: MONEY.subunits,
            price_currency: MONEY.currency_code
          )
        end
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times do
          MintingCompositeDecimal.find_by(
            price_amount: MONEY.amount,
            price_currency: MONEY.currency_code
          )
        end
      end
    when 'money_rails'
      x.report('money-rails (integer cents, currency):') do
        ITERATIONS.times do
          MoneyRailsComposite.find_by(
            price_cents: MONEY.cents,
            price_currency: MONEY.currency.to_s
          )
        end
      end
    end
  end

  # ── 5. Query: Money object (money_attribute only) ────────────

  if BENCH_SIDE == 'minting'
    puts '-' * 60
    puts 'Query by Money object (money_attribute only — composed_of decomposition)'
    puts 'money-rails cannot decompose Money in WHERE — uses raw columns above'
    puts '-' * 60

    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):') do
        ITERATIONS.times { MintingComposite.find_by(price: MONEY) }
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times { MintingCompositeDecimal.find_by(price: MONEY) }
      end
    end
  end

  # ── 6. SQL generation ────────────────────────────────────────

  puts '-' * 60
  puts 'SQL generation (.to_sql)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    case BENCH_SIDE
    when 'minting'
      x.report('money_attribute (integer column):') do
        ITERATIONS.times do
          MintingComposite.where(
            price_amount: MONEY.subunits,
            price_currency: MONEY.currency_code
          ).to_sql
        end
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times do
          MintingCompositeDecimal.where(
            price_amount: MONEY.amount,
            price_currency: MONEY.currency_code
          ).to_sql
        end
      end
    when 'money_rails'
      x.report('money-rails (integer cents, currency):') do
        ITERATIONS.times do
          MoneyRailsComposite.where(
            price_cents: MONEY.cents,
            price_currency: MONEY.currency.to_s
          ).to_sql
        end
      end
    end
  end

  # ── 6. Query: multi-record result set ─────────────────────────

  puts '-' * 60
  puts 'Query multi-record (load 100 records × 1000 iters — deserialization stress test)'
  puts '-' * 60

  BATCH_SIZE = 100
  QUERY_ITERS = 1_000

  case BENCH_SIDE
  when 'minting'
    ids_int = BATCH_SIZE.times.map { MintingComposite.create!(price: MONEY).id }

    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):') do
        QUERY_ITERS.times do
          MintingComposite.where(
            price_amount: MONEY.subunits,
            price_currency: MONEY.currency_code
          ).to_a.each(&:price)
        end
      end
    end

    MintingComposite.where(id: ids_int).delete_all

    ids_dec = BATCH_SIZE.times.map { MintingCompositeDecimal.create!(price: MONEY).id }

    Benchmark.bm(40) do |x|
      x.report('money_attribute (decimal column):') do
        QUERY_ITERS.times do
          MintingCompositeDecimal.where(
            price_amount: MONEY.amount,
            price_currency: MONEY.currency_code
          ).to_a.each(&:price)
        end
      end
    end

    MintingCompositeDecimal.where(id: ids_dec).delete_all

  when 'money_rails'
    ids_mr = BATCH_SIZE.times.map { MoneyRailsComposite.create!(price: MONEY).id }

    Benchmark.bm(40) do |x|
      x.report('money-rails (integer cents):') do
        QUERY_ITERS.times do
          MoneyRailsComposite.where(
            price_cents: MONEY.cents,
            price_currency: MONEY.currency.to_s
          ).to_a.each(&:price)
        end
      end
    end

    MoneyRailsComposite.where(id: ids_mr).delete_all
  end

  # ── 7. Arithmetic ─────────────────────────────────────────────

  if BENCH_SIDE == 'minting'
    puts '-' * 60
    puts 'Arithmetic (add two money attributes)'
    puts '-' * 60

    mc1 = MintingComposite.create!(price: MONEY)
    mc2 = MintingComposite.create!(price: MONEY)

    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):') do
        ITERATIONS.times { (mc1.price / 3) + (mc2.price * 2) }
      end
    end
  end

  # ── 8. Caching ──────────────────────────────────────────────────

  puts '-' * 60
  puts 'Repeated access ×1000 (caching demonstration)'
  puts '-' * 60
  if BENCH_SIDE == 'minting'
    puts 'composed_of used by Mint returns zero-allocation cached objects.'
    puts

    mcc   = MintingComposite.create!(price: MONEY)
    mcc_d = MintingCompositeDecimal.create!(price: MONEY)

    first = mcc.price
    second = mcc.price
    puts "money_attribute composite int same object? #{first.equal?(second)}"
    first_d = mcc_d.price
    second_d = mcc_d.price
    puts "money_attribute composite dec same object? #{first_d.equal?(second_d)}"
    puts

    Benchmark.bm(40) do |x|
      x.report('money_attribute (integer column):')  { ITERATIONS.times { mcc.price } }
      x.report('money_attribute (decimal column):')  { ITERATIONS.times { mcc_d.price } }
    end

    alloc_before = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mcc.price }
    minting_int_alloc = GC.stat(:total_allocated_objects) - alloc_before

    alloc_before = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mcc_d.price }
    minting_dec_alloc = GC.stat(:total_allocated_objects) - alloc_before

    puts
    puts format('%-40s %10s', 'money_attribute (integer column) allocated:', minting_int_alloc.to_s)
    puts format('%-40s %10s', 'money_attribute (decimal column) allocated:', minting_dec_alloc.to_s)

  else # money_rails
    puts 'Money-rails re-runs currency lookups and comparisons on every read.'
    puts

    mrcc = MoneyRailsComposite.create!(price: MONEY)

    first_mr = mrcc.price
    second_mr = mrcc.price
    puts "money-rails composite int same object? #{first_mr.equal?(second_mr)}"
    puts

    Benchmark.bm(40) do |x|
      x.report('money-rails (integer cents):') { ITERATIONS.times { mrcc.price } }
    end

    alloc_before = GC.stat(:total_allocated_objects)
    ITERATIONS.times { mrcc.price }
    money_alloc = GC.stat(:total_allocated_objects) - alloc_before

    puts
    puts format('%-40s %10s', 'money-rails (integer cents) allocated:', money_alloc.to_s)
  end
  puts

  # ── Scaling ───────────────────────────────────────────────────────

  puts
  puts '─' * 60
  puts 'Scaling: mass insert and bulk update at various batch sizes'
  puts '─' * 60

  BATCH_SIZES = [100, 500, 1000, 2000].freeze

  case BENCH_SIDE
  when 'minting'
    puts
    puts format('%-8s %-18s %-18s %-18s %-18s', 'size', 'int insert', 'int update', 'dec insert', 'dec update')

    BATCH_SIZES.each do |n|
      records_i = n.times.map { MintingComposite.new(price: MONEY) }

      t_ins_i = Benchmark.measure do
        MintingComposite.transaction { records_i.each(&:save!) }
      end

      ids_i = records_i.map(&:id)
      bu_b = Mint::Money.from(AMOUNT + 1, CURRENCY_CODE)
      t_up_i = Benchmark.measure do
        MintingComposite.update(ids_i, ids_i.each_with_index.map do |_id, i|
          { price: i.even? ? MONEY : bu_b }
        end)
      end

      MintingComposite.delete_all

      records_d = n.times.map { MintingCompositeDecimal.new(price: MONEY) }

      t_ins_d = Benchmark.measure do
        MintingCompositeDecimal.transaction { records_d.each(&:save!) }
      end

      ids_d = records_d.map(&:id)
      t_up_d = Benchmark.measure do
        MintingCompositeDecimal.update(ids_d, ids_d.each_with_index.map do |_id, i|
          { price: i.even? ? MONEY : bu_b }
        end)
      end

      MintingCompositeDecimal.delete_all

      puts format('%-8s %-18s %-18s %-18s %-18s',
                  "#{n}:", "#{t_ins_i.real.round(4)}s", "#{t_up_i.real.round(4)}s",
                  "#{t_ins_d.real.round(4)}s", "#{t_up_d.real.round(4)}s")
    end

  when 'money_rails'
    puts
    puts format('%-8s %-18s %-18s', 'size', 'mr insert', 'mr update')

    BATCH_SIZES.each do |n|
      records = n.times.map { MoneyRailsComposite.new(price: MONEY) }

      t_ins = Benchmark.measure do
        MoneyRailsComposite.transaction { records.each(&:save!) }
      end

      ids = records.map(&:id)
      bu_b = Money.from_amount(AMOUNT + 1, CURRENCY_CODE)
      t_up = Benchmark.measure do
        MoneyRailsComposite.update(ids, ids.each_with_index.map do |_id, i|
          { price: i.even? ? MONEY : bu_b }
        end)
      end

      MoneyRailsComposite.delete_all

      puts format('%-8s %-18s %-18s', "#{n}:", "#{t_ins.real.round(4)}s", "#{t_up.real.round(4)}s")
    end
  end

# ── Cleanup ─────────────────────────────────────────────────────
rescue StandardError => e
  puts "\nError: #{e.class}: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  raise
ensure
  ActiveRecord::Schema.define do
    TABLES.each { |t| drop_table t, force: true }
  end

  puts
  puts 'Done. Temporary tables dropped.'
end
# rubocop:enable Style/FormatStringToken, Metrics/BlockLength
