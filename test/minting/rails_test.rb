# frozen_string_literal: true

require 'test_helper'

module Mint
  class RailsTest < ActiveSupport::TestCase
    setup do
      @original_locale_backend = Mint.locale_backend
      @original_locale = I18n.locale
    end

    teardown do
      Mint.locale_backend = @original_locale_backend
      I18n.locale = @original_locale
    end

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

    test 'locale backend is configured and returns defaults' do
      assert_respond_to Mint.locale_backend, :call
      result = Mint.locale_backend.call
      assert_kind_of Hash, result
      assert_includes result.keys, :decimal
      assert_includes result.keys, :thousand
      assert_includes result.keys, :format
    end

    test 'locale backend reads from Rails I18n for current locale' do
      I18n.locale = :en

      result = Mint.locale_backend.call
      assert_equal '.', result[:decimal]
      assert_equal ',', result[:thousand]
      assert_equal '%<symbol>s%<amount>f', result[:format]
    end

    test 'format string is mapped from Rails to minting syntax' do
      Mint.locale_backend = -> {
        { decimal: ',', thousand: '.', format: '%<amount>f %<symbol>s' }
      }
      result = Mint.locale_backend.call
      assert_equal '%<amount>f %<symbol>s', result[:format]

      Mint.locale_backend = -> {
        { decimal: '.', thousand: ',', format: '%<symbol>s%<amount>f' }
      }
      result = Mint.locale_backend.call
      assert_equal '%<symbol>s%<amount>f', result[:format]
    end

    test 'locale backend formats money with locale-aware separators' do
      Mint.locale_backend = -> {
        { decimal: ',', thousand: '.', format: '%<symbol>s %<amount>f' }
      }
      money = Mint.money(1234.56, 'USD')
      assert_equal '$ 1.234,56', money.to_s
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
