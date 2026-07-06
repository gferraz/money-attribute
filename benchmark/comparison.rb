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
  require_relative '../test/dummy/config/environment'
when 'money_rails'
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

  # ── 4. Query ──────────────────────────────────────────────────

  puts '-' * 60
  puts 'Query (raw column values — both query the same way)'
  puts '-' * 60

  Benchmark.bm(40) do |x|
    case BENCH_SIDE
    when 'minting'
      MintingComposite.create!(price: MONEY)
      MintingCompositeDecimal.create!(price: MONEY)

      x.report('money_attribute (integer column):') do
        ITERATIONS.times { MintingComposite.find_by(price: MONEY) }
      end
      x.report('money_attribute (decimal column):') do
        ITERATIONS.times { MintingCompositeDecimal.find_by(price: MONEY) }
      end
    when 'money_rails'
      MoneyRailsComposite.create!(price: MONEY)

      x.report('money-rails (integer cents):') do
        ITERATIONS.times do
          MoneyRailsComposite.find_by(price_cents: MONEY,
                                      price_currency: MONEY.currency)
        end
      end
    end
  end

  # ── 5. Arithmetic ─────────────────────────────────────────────

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

  # ── 6. Caching ──────────────────────────────────────────────────

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

  # ── Mass insert ─────────────────────────────────────────────────

  puts
  puts '─' * 60
  puts "Mass insert (#{NUM_RECORDS} records in transaction, Money through setter)"
  puts '─' * 60

  case BENCH_SIDE
  when 'minting'
    mass_minting_composite = Benchmark.measure do
      MintingComposite.transaction do
        NUM_RECORDS.times { MintingComposite.create!(price: MONEY) }
      end
    end
    mass_minting_composite_decimal = Benchmark.measure do
      MintingCompositeDecimal.transaction do
        NUM_RECORDS.times { MintingCompositeDecimal.create!(price: MONEY) }
      end
    end

    puts format('%-40s %10s', 'money_attribute (integer column):',
                "#{mass_minting_composite.real.round(4)}s")
    puts format('%-40s %10s', 'money_attribute (decimal column):',
                "#{mass_minting_composite_decimal.real.round(4)}s")

  when 'money_rails'
    mass_money_rails_composite = Benchmark.measure do
      MoneyRailsComposite.transaction do
        NUM_RECORDS.times { MoneyRailsComposite.create!(price: MONEY) }
      end
    end

    puts format('%-40s %10s', 'money-rails (integer cents):',
                "#{mass_money_rails_composite.real.round(4)}s")
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
