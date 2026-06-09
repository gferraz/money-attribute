# frozen_string_literal: true

require 'test_helper'

module Mint
  class MoneyAttributeTest < ActiveSupport::TestCase
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

      assert_equal Mint.money(12, Mint.default_currency), offer.price
      assert_equal 12, offer.price_amount
      assert_equal Mint.default_currency.code, offer.price_currency
    end

    test 'aggregated money attribute is saved correctly' do
      offer = Offer.new(price: 15.euros)
      offer.save!

      assert_equal offer.price, Offer.where(price: 15.euros).first
      assert_equal offer.price, Offer.where(price_amount: 15.00, price_currency: 'EUR').first
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

    test 'aggregated money attribute with integer amount column' do
      transaction = FinancialTransaction.new(value: 45.34.dollars)

      assert_equal 45.34.dollars, transaction.value
      assert_equal 4534, transaction.amount
      assert_equal 'USD', transaction.currency
    end

    test 'aggregated money attribute supports custom mappings' do
      mapped_offer = Class.new(ApplicationRecord) do
        self.table_name = 'offers'

        money_attribute :cost, mapping: {
          price_amount: :amount,
          price_currency: :currency
        }
      end

      offer = mapped_offer.new(cost: 19.euros)

      assert_equal 19.euros, offer.cost
      assert_equal 19, offer.price_amount
      assert_equal 'EUR', offer.price_currency
    end

    test 'aggregated money attribute requires backing amount and currency columns' do
      invalid_offer = Class.new(ApplicationRecord) do
        self.table_name = 'offers'
      end

      assert_raises(ArgumentError) { invalid_offer.money_attribute :missing_price }
      assert_raises(ArgumentError) do
        invalid_offer.money_attribute :cost, mapping: { price_amount: :amount }
      end
    end

    test 'parse keeps money values unchanged' do
      parser = MoneyAttribute::Parser.new('USD')

      assert_equal 23.euros, parser.parse("+23.00", 'EUR')
      assert_equal 23.euros, parser.parse(23, 'EUR')
      assert_equal (-25.34).dollars, parser.parse("-25.34")
      assert_equal (-25.34).dollars, parser.parse("-25.34 EUR")
      assert_nil MoneyAttribute::Parser.new.parse(nil, 'USD')
      assert_raises(TypeError) { parser.parse(23.euros, 'USD') }
    end

    test 'aggregated money attribute partial custom mapping' do
      assert_raises(ArgumentError) do
        Class.new(ApplicationRecord) do
          self.table_name = 'offers'

          money_attribute :cost, mapping: {
            price_amount: :amount
          }
        end
      end
    end
  end
end
