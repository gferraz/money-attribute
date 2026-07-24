# frozen_string_literal: true

require 'test_helper'

class CurrentTest < ActiveSupport::TestCase
  test 'Current.currency is nil by default' do
    assert_nil MoneyAttribute::Current.currency
  end

  test 'Current.currency can be set and read' do
    MoneyAttribute::Current.currency = 'EUR'

    assert_equal 'EUR', MoneyAttribute::Current.currency
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Current.currency is thread-safe' do
    threads = Array.new(10) do |i|
      Thread.new do # rubocop:disable ThreadSafety/NewThread
        MoneyAttribute::Current.currency = "C#{i}"
        sleep 0.01

        assert_equal "C#{i}", MoneyAttribute::Current.currency
      end
    end
    threads.each(&:join)
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Current.currency is reset after reset call' do
    MoneyAttribute::Current.currency = 'EUR'
    MoneyAttribute::Current.reset

    assert_nil MoneyAttribute::Current.currency
  end

  test 'default_currency returns Current.currency when set' do
    MoneyAttribute::Current.currency = 'EUR'

    assert_equal 'EUR', MoneyAttribute.default_currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'default_currency falls back to config when Current.currency is nil' do
    MoneyAttribute::Current.reset

    assert_equal MoneyAttribute.config.default_currency, MoneyAttribute.default_currency.code
  end

  test 'default_currency falls back to config when Current.currency is blank' do
    MoneyAttribute::Current.currency = ''

    assert_equal MoneyAttribute.config.default_currency, MoneyAttribute.default_currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Converter uses per-request currency for numeric input' do
    converter = MoneyAttribute::Converter.new
    MoneyAttribute::Current.currency = 'EUR'
    money = converter.parse(100)

    assert_equal 'EUR', money.currency.code
    assert_equal 100, money.amount
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Converter uses per-request currency for string input' do
    converter = MoneyAttribute::Converter.new
    MoneyAttribute::Current.currency = 'GBP'
    money = converter.parse('50.25')

    assert_equal 'GBP', money.currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Converter uses static currency when provided' do
    converter = MoneyAttribute::Converter.new('AUD')
    money = converter.parse(100)

    assert_equal 'AUD', money.currency.code
  end

  test 'Type uses per-request currency' do
    type = MoneyAttribute::Type.new(column_type: ActiveRecord::Type::Decimal.new)
    MoneyAttribute::Current.currency = 'CHF'
    money = type.cast('100')

    assert_equal 'CHF', money.currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'Type uses static currency when provided' do
    currency = Mint::Currency.resolve!('NZD')
    type = MoneyAttribute::Type.new(currency: currency, column_type: ActiveRecord::Type::Decimal.new)
    money = type.cast('100')

    assert_equal 'NZD', money.currency.code
  end

  test 'composite Converter uses per-request currency for numeric assignment' do
    offer = Offer.new
    MoneyAttribute::Current.currency = 'EUR'
    offer.price = 42

    assert_equal 'EUR', offer.price_currency
    assert_equal 42, offer.price_amount
  ensure
    MoneyAttribute::Current.reset
  end

  test 'composite Converter uses per-request currency for string assignment' do
    offer = Offer.new
    MoneyAttribute::Current.currency = 'GBP'
    offer.price = '42'

    assert_equal 'GBP', offer.price_currency
    assert_equal 42, offer.price_amount
  ensure
    MoneyAttribute::Current.reset
  end

  test 'composite constructor falls back to per-request currency for nil DB currency' do
    offer = Offer.new
    offer.price_amount = 12.0
    offer.price_currency = nil
    MoneyAttribute::Current.currency = 'SEK'

    assert_equal 'SEK', offer.price.currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'per-request currency persists through save and reload in composite mode' do
    offer = Offer.new
    MoneyAttribute::Current.currency = 'USD'
    offer.price = 42
    offer.save!
    offer.reload

    assert_equal 'USD', offer.price.currency.code
    assert_equal 'USD', offer.price_currency
  ensure
    MoneyAttribute::Current.reset
  end

  test 'per-request currency changes between writes in composite mode' do
    offer = Offer.new

    MoneyAttribute::Current.currency = 'USD'
    offer.price = 100

    assert_equal 'USD', offer.price.currency.code
    assert_equal 'USD', offer.price_currency

    MoneyAttribute::Current.currency = 'EUR'
    offer.price = 200

    assert_equal 'EUR', offer.price.currency.code
    assert_equal 'EUR', offer.price_currency
  ensure
    MoneyAttribute::Current.reset
  end

  test 'single-column money_amount uses per-request currency' do
    item = SimpleOffer.new
    MoneyAttribute::Current.currency = 'GBP'
    item.price = 50

    assert_equal 'GBP', item.price.currency.code
  ensure
    MoneyAttribute::Current.reset
  end

  test 'per-request currency with FinancialTransaction (composite, integer column)' do
    ft = FinancialTransaction.new
    MoneyAttribute::Current.currency = 'CAD'
    ft.amount = 42

    assert_equal 'CAD', ft.amount.currency.code
    assert_equal 'CAD', ft.currency
  ensure
    MoneyAttribute::Current.reset
  end
end
