# frozen_string_literal: true

require 'test_helper'

module Mint
  class RailsTest < ActiveSupport::TestCase
    test 'it has a version number' do
      assert Mint::MoneyAttribute::VERSION
      assert Minting::VERSION
    end

    test 'default currency configuration' do
      assert_equal 'BRL', Mint.default_currency.code
    end

    test 'configure resets cached default currency' do
      Mint.default_currency

      with_mint_config(default_currency: 'USD') do
        assert_equal 'USD', Mint.default_currency.code
      end
    end

    test 'configuration has defaults without Active Support configurable' do
      config = Mint::MoneyAttribute::Configuration.new

      assert_empty config.added_currencies
      assert_equal 'USD', config.default_currency
      assert_nil config.rounding_mode
      assert_nil config.default_format
    end

    private

    def with_mint_config(overrides)
      original = {
        added_currencies: Mint.config.added_currencies,
        default_currency: Mint.config.default_currency,
        rounding_mode: Mint.config.rounding_mode,
        default_format: Mint.config.default_format
      }

      Mint.configure do |config|
        overrides.each { |key, value| config.public_send("#{key}=", value) }
      end

      yield
    ensure
      Mint.configure do |config|
        original.each { |key, value| config.public_send("#{key}=", value) }
      end
    end
  end
end
