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

    test 'enable currencies configuration' do
      assert_equal :all, Mint.config.enabled_currencies
      assert_equal Mint.currency('BRL'), Mint.assert_valid_currency!('BRL')
      assert_equal Mint.currency('USD'), Mint.assert_valid_currency!('USD')
      assert_raises(ArgumentError) {  Mint.assert_valid_currency!('XPX') }
      assert_raises(ArgumentError) {  Mint.assert_valid_currency!('XPX') }
      assert_raises(ArgumentError) {  Mint.assert_valid_currency!(12) }
      assert_raises(ArgumentError) {  Mint.assert_valid_currency!(nil) }
    end

    test 'custom currencies from configuration are registered' do
      assert_equal Mint.currency('CRC'), Mint.assert_valid_currency!('CRC')
      assert_equal Mint.currency('NGN'), Mint.assert_valid_currency!('NGN')
    end

    test 'enabled currencies can limit valid currencies' do
      with_mint_config(enabled_currencies: %w[USD], default_currency: 'USD') do
        assert Mint.valid_currency?(Mint.currency('USD'))
        refute Mint.valid_currency?(Mint.currency('BRL'))
        assert_equal Mint.currency('USD'), Mint.assert_valid_currency!(:USD)
        assert_raises(ArgumentError) { Mint.assert_valid_currency!(:BRL) }
      end
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
      assert_equal :all, config.enabled_currencies
      assert_equal 'USD', config.default_currency
      assert_nil config.rounding_mode
      assert_nil config.default_format
    end

    private

    def with_mint_config(overrides)
      original = {
        added_currencies: Mint.config.added_currencies,
        enabled_currencies: Mint.config.enabled_currencies,
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
