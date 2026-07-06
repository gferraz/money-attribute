# frozen_string_literal: true

require 'test_helper'

class MoneyAttributeTest < ActiveSupport::TestCase
  test 'aggregated money attribute requires backing amount and currency columns' do
    invalid_offer = Class.new(ApplicationRecord) do
      self.table_name = 'offers'
    end

    assert_raises(ArgumentError) { invalid_offer.money_attribute :missing_price }
    assert_raises(ArgumentError) do
      invalid_offer.money_attribute :cost, mapping: { price_amount: :amount }
    end
  end

  test 'find_money_attributes infers currency column from convention when mapping only amount' do
    error = assert_raises(ArgumentError) do
      Class.new(ApplicationRecord) do
        self.table_name = 'offers'

        money_attribute :cost, mapping: { amount: :price_amount }
      end
    end
    assert_includes error.message, 'Expected: price_amount, cost_currency'
  end

  test 'find_money_attributes error lists expected and found columns' do
    invalid_offer = Class.new(ApplicationRecord) do
      self.table_name = 'offers'
    end

    error = assert_raises(ArgumentError) { invalid_offer.money_attribute :missing_price }
    assert_includes error.message, 'Expected: missing_price_amount, missing_price_currency'
    assert_includes error.message, 'Found:'
  end

  test 'find_money_attributes ignores wrong mapping keys and falls back to convention' do
    error = assert_raises(ArgumentError) do
      Class.new(ApplicationRecord) do
        self.table_name = 'offers'

        money_attribute :cost, mapping: { price_amount: :amount }
      end
    end
    assert_includes error.message, 'Expected: cost_amount, cost_currency'
  end

  test 'parse keeps money values unchanged' do # rubocop:disable Minitest/MultipleAssertions
    converter = MoneyAttribute::Converter.new('USD')

    assert_equal 23.dollars, converter.call('+23.00')
    assert_equal 23.dollars, converter.call(23)
    assert_equal(-25.34.dollars, converter.call('-25.34'))
    assert_equal(-29.33.euros, converter.call('-29.33 EUR'))
    assert_nil MoneyAttribute::Converter.new.call(nil)
  end

  test 'converter returns nil for nil amount even with valid currency' do
    converter = MoneyAttribute::Converter.new('USD')

    assert_nil converter.call(nil)
  end

  test 'Numeric#to_money without currency uses default' do
    default = MoneyAttribute.default_currency
    money = 42.to_money

    assert_equal default.code, money.currency.code
    assert_in_delta 42, money.amount
  end

  test 'Numeric#to_money with explicit currency' do
    money = 42.to_money('EUR')

    assert_equal 'EUR', money.currency.code
    assert_in_delta 42, money.amount
  end

  test 'Numeric#to_money with zero' do
    money = 0.to_money

    assert_equal MoneyAttribute.default_currency.code, money.currency.code
    assert_equal 0, money.amount
  end

  test 'Numeric#to_money with negative value' do
    money = -5.50.to_money

    assert_equal MoneyAttribute.default_currency.code, money.currency.code
    assert_in_delta(-5.50, money.amount)
  end

  test 'String#to_money without currency uses default' do
    money = '12.50'.to_money

    assert_equal MoneyAttribute.default_currency.code, money.currency.code
    assert_in_delta 12.50, money.amount
  end

  test 'String#to_money with explicit currency' do
    money = '12.50'.to_money('EUR')

    assert_equal 'EUR', money.currency.code
    assert_in_delta 12.50, money.amount
  end
end
