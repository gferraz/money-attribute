# frozen_string_literal: true

require 'test_helper'

class MigrationExtensionsTest < ActiveSupport::TestCase
  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    drop_table_if_exists(:test_money_ext)
    drop_table_if_exists(:test_money_items)
    drop_table_if_exists(:reversible_test)
  end

  # --- Module inclusion ---

  test 'includes instance methods on Migration' do
    assert_includes ActiveRecord::Migration.instance_methods, :add_money_attribute
    assert_includes ActiveRecord::Migration.instance_methods, :remove_money_attribute
    assert_includes ActiveRecord::Migration.instance_methods, :add_money_amount
    assert_includes ActiveRecord::Migration.instance_methods, :remove_money_amount
  end

  test 'includes instance methods on TableDefinition' do
    assert_includes ActiveRecord::ConnectionAdapters::TableDefinition.instance_methods, :money_attribute
    assert_includes ActiveRecord::ConnectionAdapters::TableDefinition.instance_methods, :remove_money_attribute
    assert_includes ActiveRecord::ConnectionAdapters::TableDefinition.instance_methods, :money_amount
    assert_includes ActiveRecord::ConnectionAdapters::TableDefinition.instance_methods, :remove_money_amount
  end

  # --- t.money_attribute naming conventions (create_table) ---

  test 't.money_attribute :price creates price and price_currency columns' do
    create_money_table do |t|
      t.money_attribute :price
    end

    assert_columns 'price', 'price_currency'
  end

  test 't.money_attribute :price_amount uses _amount column and strips suffix for currency' do
    create_money_table do |t|
      t.money_attribute :price_amount
    end

    assert_columns 'price_amount', 'price_currency'
  end

  test 't.money_amount creates single column without currency' do
    create_money_table do |t|
      t.money_amount :price
    end

    assert_columns 'price'
    assert_no_columns 'price_currency'
    assert_column_precision_scale 'price', 20, 4
  end

  test 't.money_amount with type: :crypto_decimal creates high-precision decimal column' do
    create_money_table do |t|
      t.money_amount :btc_balance, type: :crypto_decimal
    end

    assert_columns 'btc_balance'
    assert_column_type 'btc_balance', :decimal
    assert_column_precision_scale 'btc_balance', 36, 18
  end

  test 't.money_amount with type: :fiat_integer uses bigint column' do
    create_money_table do |t|
      t.money_amount :price, type: :fiat_integer
    end

    assert_columns 'price'
  end

  test 't.money_amount with type: :fiat_decimal uses default precision and scale' do
    create_money_table do |t|
      t.money_amount :price, type: :fiat_decimal
    end

    assert_columns 'price'
    assert_column_precision_scale 'price', 20, 4
  end

  test 't.money_amount with amount type creates integer column' do
    create_money_table do |t|
      t.money_amount :price, type: :fiat_integer
    end

    assert_column_type 'price', :integer
  end

  test 't.money_attribute with amount type creates integer column' do
    create_money_table do |t|
      t.money_attribute :price, amount: { type: :fiat_integer }
    end

    assert_column_type 'price', :integer
  end

  test 't.money_attribute does not accept precision and scale' do
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_attribute :price, amount: { type: :fiat_integer, precision: 10, scale: 2 }
      end
    end
  end

  test 't.money_attribute with explicit amount and currency mapping' do
    create_money_table do |t|
      t.money_attribute :price, amount: { column: :the_price }, currency: { column: :the_currency }
    end

    assert_columns 'the_price', 'the_currency'
  end

  test 't.money_attribute with explicit amount mapping only' do
    create_money_table do |t|
      t.money_attribute :price, amount: { column: :the_price }
    end

    assert_columns 'the_price', 'price_currency'
  end

  test 't.money_attribute with explicit currency mapping only' do
    create_money_table do |t|
      t.money_attribute :price, currency: { column: :code }
    end

    assert_columns 'price', 'code'
  end

  test 't.money_attribute with currency limit sets string limit' do
    create_money_table do |t|
      t.money_attribute :price, currency: { limit: 90 }
    end

    col = @connection.columns(:test_money_ext).find { |c| c.name == 'price_currency' }

    assert_equal 90, col.limit
  end

  # --- change_table ---

  test 't.money_attribute works inside change_table block' do
    @connection.create_table(:test_money_items, force: true)

    @connection.change_table(:test_money_items) do |t|
      t.money_attribute :price
    end

    assert_columns('price', 'price_currency', table: :test_money_items)
  end

  # --- add_money_attribute via migration ---

  test 'add_money_attribute creates columns via migration' do
    @connection.create_table(:test_money_items, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :test_money_items, :price
      end
    end.new('Test', 1)

    migration.migrate(:up)

    assert_columns('price', 'price_currency', table: :test_money_items)
  end

  # --- Reversibility ---

  test 'add_money_attribute in change is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :reversible_test, :price
      end
    end.new('ReversibleTest', 2)

    migration.migrate(:up)

    assert_columns('price', 'price_currency', table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('price', 'price_currency', table: :reversible_test)
  end

  test 'add_money_amount in change is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_amount :reversible_test, :fee
      end
    end.new('ReversibleTest', 3)

    migration.migrate(:up)

    assert_columns('fee', table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('fee', table: :reversible_test)
  end

  test 'add_money_attribute with fiat_integer is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :reversible_test, :price, amount: { type: :fiat_integer }
      end
    end.new('ReversibleTest', 6)

    migration.migrate(:up)

    assert_columns('price', 'price_currency', table: :reversible_test)
    assert_column_type('price', :integer, table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('price', 'price_currency', table: :reversible_test)
  end

  test 'add_money_attribute with custom column mapping is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :reversible_test, :price, amount: { column: :the_price },
                                                      currency: { column: :code }
      end
    end.new('ReversibleTest', 7)

    migration.migrate(:up)

    assert_columns('the_price', 'code', table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('the_price', 'code', table: :reversible_test)
  end

  test 'add_money_attribute with crypto_decimal is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :reversible_test, :btc, amount: { type: :crypto_decimal }
      end
    end.new('ReversibleTest', 8)

    migration.migrate(:up)

    assert_columns('btc', 'btc_currency', table: :reversible_test)
    assert_column_precision_scale('btc', 36, 18, table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('btc', 'btc_currency', table: :reversible_test)
  end

  test 'add_money_attribute with currency limit is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :reversible_test, :price, currency: { limit: 10 }
      end
    end.new('ReversibleTest', 9)

    migration.migrate(:up)
    col = @connection.columns(:reversible_test).find { |c| c.name == 'price_currency' }

    assert_equal 10, col.limit

    migration.migrate(:down)

    assert_no_columns('price', 'price_currency', table: :reversible_test)
  end

  test 'add_money_amount with custom type is reversible' do
    @connection.create_table(:reversible_test, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_amount :reversible_test, :fee, type: :crypto_decimal
      end
    end.new('ReversibleTest', 10)

    migration.migrate(:up)

    assert_columns('fee', table: :reversible_test)
    assert_column_precision_scale('fee', 36, 18, table: :reversible_test)

    migration.migrate(:down)

    assert_no_columns('fee', table: :reversible_test)
  end

  test 'remove_money_amount drops single column' do
    @connection.create_table(:test_money_items, force: true) do |t|
      t.money_amount :fee
    end

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        remove_money_amount :test_money_items, :fee
      end
    end.new('Test', 5)

    migration.migrate(:up)

    assert_no_columns('fee', table: :test_money_items)
  end

  # --- remove_money_attribute via migration ---

  # --- Validation edge cases ---

  test 'add_money_amount rejects precision or scale' do
    @connection.create_table(:test_money_items, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_amount :test_money_items, :price, precision: 10
      end
    end.new('Test', 100)
    assert_raises(ArgumentError) { migration.migrate(:up) }

    migration2 = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_amount :test_money_items, :price, scale: 2
      end
    end.new('Test', 101)
    assert_raises(ArgumentError) { migration2.migrate(:up) }
  end

  test 'add_money_amount rejects invalid type' do
    @connection.create_table(:test_money_items, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_amount :test_money_items, :price, type: :bogus
      end
    end.new('Test', 102)

    assert_raises(ArgumentError) { migration.migrate(:up) }
  end

  test 't.money_amount rejects precision or scale' do
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_amount :price, precision: 10
      end
    end
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_amount :price, scale: 2
      end
    end
  end

  test 't.money_amount rejects invalid type' do
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_amount :price, type: :bogus
      end
    end
  end

  test 'add_money_attribute rejects small currency limit' do
    @connection.create_table(:test_money_items, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :test_money_items, :price, currency: { limit: 3 }
      end
    end.new('Test', 103)

    assert_raises(ArgumentError) { migration.migrate(:up) }
  end

  test 't.money_attribute rejects small currency limit' do
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_attribute :price, currency: { limit: 3 }
      end
    end
  end

  test 'add_money_attribute rejects invalid amount type' do
    @connection.create_table(:test_money_items, force: true)

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        add_money_attribute :test_money_items, :price, amount: { type: :bogus }
      end
    end.new('Test', 104)

    assert_raises(ArgumentError) { migration.migrate(:up) }
  end

  test 't.money_attribute rejects invalid amount type' do
    assert_raises(ArgumentError) do
      create_money_table do |t|
        t.money_attribute :price, amount: { type: :bogus }
      end
    end
  end

  test 'remove_money_attribute drops columns via migration' do
    @connection.create_table(:test_money_items, force: true) do |t|
      t.money_attribute :price
    end

    migration = Class.new(ActiveRecord::Migration[8.1]) do
      def change
        remove_money_attribute :test_money_items, :price
      end
    end.new('Test', 4)

    migration.migrate(:up)

    assert_no_columns('price', 'price_currency', table: :test_money_items)
  end

  private

  def create_money_table(&)
    @connection.create_table(:test_money_ext, force: true, &)
  end

  def assert_columns(*expected, table: :test_money_ext)
    cols = @connection.columns(table).map(&:name)

    expected.each { |c| assert_includes cols, c.to_s }
  end

  def assert_no_columns(*unexpected, table: :test_money_ext)
    cols = @connection.columns(table).map(&:name)

    unexpected.each { |c| assert_not_includes cols, c.to_s }
  end

  def assert_column_type(column_name, expected_type, table: :test_money_ext)
    col = @connection.columns(table).find { |c| c.name == column_name.to_s }

    assert_equal expected_type, col.type
  end

  def assert_column_precision_scale(column_name, expected_precision, expected_scale, table: :test_money_ext)
    col = @connection.columns(table).find { |c| c.name == column_name.to_s }

    assert_equal expected_precision, col.precision
    assert_equal expected_scale, col.scale
  end

  def drop_table_if_exists(name)
    @connection.drop_table(name) if @connection.table_exists?(name)
  rescue StandardError
    nil
  end
end
