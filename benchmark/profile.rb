# frozen_string_literal: true

# CPU profiler for money_attribute hot paths.
#
# Usage:
#   bundle exec ruby benchmark/profile.rb              # profile all modes
#   bundle exec ruby benchmark/profile.rb string_query  # profile a single mode
#
# Modes: string_query, pluck, read_cached, multi_record, arithmetic, all

require_relative 'shared'
require 'money_attribute'
require 'stackprof'

# --- Setup ---

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
end

setup_schema
define_models

$money = Mint::Money.from(AMOUNT, CURRENCY_CODE)
$alt_money = Mint::Money.from(AMOUNT_ALT, CURRENCY_CODE)

# Seed data
100.times { MintingComposite.create!(price: $money) }
record = MintingComposite.create!(price: $money)

# --- Profile modes ---

MODES = {
  'string_query' => -> {
    money = $money
    20_000.times do
      MintingComposite.where_amount('price < ?', money)
      MintingComposite.where_amount('price >= ? AND price <= ?', money, $alt_money)
      MintingComposite.where_amount('NOT price = ?', money)
      MintingComposite.where_amount('price IS NULL')
    end
  },

  'pluck' => -> {
    10_000.times { MintingComposite.pluck_amount(:price) }
  },

  'read_cached' => -> {
    rec = MintingComposite.find(record.id)
    100_000.times { rec.price }
  },

  'multi_record' => -> {
    ids = MintingComposite.limit(100).pluck(:id)
    500.times { MintingComposite.where(id: ids).each(&:price) }
  },

  'arithmetic' => -> {
    rec1 = MintingComposite.find(record.id)
    rec2 = MintingComposite.create!(price: $alt_money)
    50_000.times { (rec1.price / 3) + (rec2.price * 2) }
  },

  'all' => -> {
    MODES.reject { |k, _| k == 'all' }.each_value(&:call)
  }
}.freeze

# --- Run ---

mode = ARGV[0] || 'all'
raise "Unknown mode: #{mode}" unless MODES.key?(mode)

out_path = File.expand_path("../tmp/stackprof-#{mode}.dump", __dir__)

puts '=' * 60
puts "Profiling: #{mode}"
puts "Ruby #{RUBY_VERSION}, Rails #{Gem.loaded_specs['rails']&.version || '?'}"
puts "Samples: CPU mode"
puts '=' * 60
puts

StackProf.run(mode: :cpu, out: out_path, raw: true) do
  MODES[mode].call
end

puts
puts "Profile written: #{out_path}"
puts

# Print text report
report = StackProf::Report.new(Marshal.load(File.binread(out_path)))
report.print_text

puts
puts '=' * 60
puts 'Flamegraph: stackprof --stackcollapse tmp/stackprof-#{mode}.dump | flamegraph.pl > tmp/flamegraph-#{mode}.svg'
puts '=' * 60
