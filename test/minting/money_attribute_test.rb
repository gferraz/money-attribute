# frozen_string_literal: true

require 'test_helper'

module Mint
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

    test 'parse keeps money values unchanged' do
      parser = MoneyAttribute::Parser.new('USD')

      assert_equal 23.euros, parser.parse('+23.00', 'EUR')
      assert_equal 23.euros, parser.parse(23, 'EUR')
      assert_equal(-25.34.dollars, parser.parse('-25.34'))
      assert_equal(-25.34.dollars, parser.parse('-25.34 EUR'))
      assert_nil MoneyAttribute::Parser.new.parse(nil, 'USD')
      assert_raises(TypeError) { parser.parse(23.euros, 'USD') }
    end
  end
end
