# frozen_string_literal: true

require 'test_helper'

class CompositeMoneyAttributeTest < ActiveSupport::TestCase
  test 'Money attribute is enabled' do
    assert Offer.attribute :price
  end

  test 'aggregated money attribute updates mapped attributes' do
    offer = Offer.new(price: 12.dollars)

    assert_equal 12.dollars, offer.price
    assert_equal 12, offer.price_amount
    assert_equal 'USD', offer.price_currency
  end

  test 'aggregated money attribute parses any amount to the default currency' do
    offer = Offer.new(price: '12')

    assert_equal Mint.money(12, MoneyAttribute.default_currency), offer.price
    assert_equal 12, offer.price_amount
    assert_equal MoneyAttribute.default_currency.code, offer.price_currency
  end

  test 'aggregated money attribute is saved correctly' do
    offer = Offer.new(price: 15.euros)
    offer.save!

    assert_equal offer.price, Offer.where(price: 15.euros).first.price
    assert_equal offer.price, Offer.where(price_amount: 15.00, price_currency: 'EUR').first.price
    assert_empty Offer.where(price: 15.dollars)
  end

  test 'aggregated money attribute reads from mapped amount and currency columns' do
    offer = Offer.new(price_amount: 17.01, price_currency: 'USD')

    assert_equal 17.01.dollars, offer.price
  end

  test 'aggregated money attribute allows nil values' do
    offer = Offer.new(price: nil)

    assert_nil offer.price
    assert_nil offer.price_amount
    assert_nil offer.price_currency
  end

  test 'aggregated money attribute supports custom mappings' do
    mapped_offer = Class.new(ApplicationRecord) do
      self.table_name = 'offers'

      money_attribute :cost, mapping: {
        amount: :price_amount,
        currency: :price_currency
      }
    end

    offer = mapped_offer.new(cost: 19.euros)

    assert_equal 19.euros, offer.cost
    assert_equal 19, offer.price_amount
    assert_equal 'EUR', offer.price_currency
  end

  test 'composite money attribute reads from directly written columns' do
    offer = Offer.new(price_amount: 25, price_currency: 'EUR')

    assert_equal 25.euros, offer.price
  end

  test 'composite money attribute accepts zero' do
    offer = Offer.new(price: 0.dollars)

    assert_equal 0.dollars, offer.price
    offer.save!

    assert_equal 0.dollars, offer.reload.price
  end

  test 'composite money attribute accepts negative values' do
    offer = Offer.new(price: -5.50.dollars)

    assert_equal(-5.50.dollars, offer.price)
    offer.save!

    assert_equal(-5.50.dollars, offer.reload.price)
  end

  test 'aggregated money attribute partial custom mapping for currency only' do
    mapped = Class.new(ApplicationRecord) do
      self.table_name = 'offers'

      money_attribute :price, mapping: { currency: :price_currency }
    end

    offer = mapped.new(price: 19.euros)

    assert_equal 19.euros, offer.price
    assert_equal 19, offer.price_amount
    assert_equal 'EUR', offer.price_currency
  end

  test 'aggregated money attribute partial custom mapping for amount only' do
    mapped = Class.new(ApplicationRecord) do
      self.table_name = 'offers'

      money_attribute :price, mapping: { amount: :price_amount }
    end

    offer = mapped.new(price: 19.euros)

    assert_equal 19.euros, offer.price
    assert_equal 19, offer.price_amount
    assert_equal 'EUR', offer.price_currency
  end
end
