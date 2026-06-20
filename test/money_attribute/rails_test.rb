# frozen_string_literal: true

require 'test_helper'

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
    assert MoneyAttribute::VERSION
  end

  test 'default currency configuration' do
    assert_equal 'BRL', MoneyAttribute.default_currency.code
  end

  test 'configure resets cached default currency' do
    MoneyAttribute.default_currency

    with_money_attribute_config(default_currency: 'USD') do
      assert_equal 'USD', MoneyAttribute.default_currency.code
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
    Mint.locale_backend = lambda {
      { decimal: ',', thousand: '.', format: '%<amount>f %<symbol>s' }
    }
    result = Mint.locale_backend.call

    assert_equal '%<amount>f %<symbol>s', result[:format]

    Mint.locale_backend = lambda {
      { decimal: '.', thousand: ',', format: '%<symbol>s%<amount>f' }
    }
    result = Mint.locale_backend.call

    assert_equal '%<symbol>s%<amount>f', result[:format]
  end

  test 'locale backend formats money with locale-aware separators' do
    Mint.locale_backend = lambda {
      { decimal: ',', thousand: '.', format: '%<symbol>s %<amount>f' }
    }
    money = Mint.money(1234.56, 'USD')

    assert_equal '$ 1.234,56', money.to_s
  end

  test 'locale backend returns string format when no per-sign keys' do
    Mint.locale_backend = lambda {
      { decimal: '.', thousand: ',', format: '%<symbol>s%<amount>f' }
    }
    result = Mint.locale_backend.call

    assert_kind_of String, result[:format]
    assert_equal '%<symbol>s%<amount>f', result[:format]
  end

  test 'locale backend returns hash format when positive key is present' do
    Mint.locale_backend = lambda {
      gsub = ->(s) { s&.gsub('%n', '%<amount>f')&.gsub('%u', '%<symbol>s') }
      fmt = { format: '%u%n', positive: '%u%n', separator: '.', delimiter: ',' }
      {
        decimal: fmt[:separator],
        thousand: fmt[:delimiter],
        format: if fmt.key?(:positive) || fmt.key?(:negative) || fmt.key?(:zero)
                  {
                    positive: gsub.call(fmt[:positive] || fmt[:format]),
                    negative: gsub.call(fmt[:negative] || fmt[:format]),
                    zero: gsub.call(fmt[:zero] || fmt[:format])
                  }
                else
                  gsub.call(fmt[:format])
                end
      }
    }
    result = Mint.locale_backend.call

    assert_kind_of Hash, result[:format]
    assert_includes result[:format], :positive
    assert_includes result[:format], :negative
    assert_includes result[:format], :zero
  end

  test 'locale backend hash format respects negative and zero overrides' do
    Mint.locale_backend = lambda {
      gsub = ->(s) { s&.gsub('%n', '%<amount>f')&.gsub('%u', '%<symbol>s') }
      fmt = { format: '%u%n', negative: '(%u%n)', zero: '--', separator: '.', delimiter: ',' }
      {
        decimal: fmt[:separator],
        thousand: fmt[:delimiter],
        format: if fmt.key?(:positive) || fmt.key?(:negative) || fmt.key?(:zero)
                  positive = gsub.call(fmt[:positive] || fmt[:format])
                  negative = gsub.call(fmt[:negative] || fmt[:format])
                  zero = gsub.call(fmt[:zero] || fmt[:format])
                  { positive:, negative:, zero: }
                else
                  gsub.call(fmt[:format])
                end
      }
    }

    positive = Mint.money(10.00, 'USD')
    negative = Mint.money(-10.00, 'USD')
    zero     = Mint.money(0, 'USD')

    assert_equal '$10.00', positive.to_s
    assert_equal '($10.00)', negative.to_s
    assert_equal '--', zero.to_s
  end

  test 'locale backend hash format falls back to format for missing per-sign keys' do
    Mint.locale_backend = lambda {
      gsub = ->(s) { s&.gsub('%n', '%<amount>f')&.gsub('%u', '%<symbol>s') }
      fmt = { format: '[%u%n]', negative: '(%u%n)', separator: '.', delimiter: ',' }
      {
        decimal: fmt[:separator],
        thousand: fmt[:delimiter],
        format: if fmt.key?(:positive) || fmt.key?(:negative) || fmt.key?(:zero)
                  {
                    positive: gsub.call(fmt[:positive] || fmt[:format]),
                    negative: gsub.call(fmt[:negative] || fmt[:format]),
                    zero: gsub.call(fmt[:zero] || fmt[:format])
                  }
                else
                  gsub.call(fmt[:format])
                end
      }
    }

    assert_equal '[$10.00]',   Mint.money(10.00, 'USD').to_s
    assert_equal '($10.00)',   Mint.money(-10.00, 'USD').to_s
    assert_equal '[$0.00]',    Mint.money(0, 'USD').to_s
  end

  test 'configuration has defaults without Active Support configurable' do
    config = MoneyAttribute::Configuration.new

    assert_empty config.added_currencies
    assert_equal 'USD', config.default_currency
    assert_nil config.default_format
  end

  test 'added_currencies registers custom currencies' do
    with_money_attribute_config(added_currencies: [
                                   { currency: 'CFGA', subunit: 2, symbol: 'A' },
                                   { currency: 'CFGB', subunit: 3, symbol: 'B' }
                                 ]) do
      c = Mint::Currency.for_code('CFGA')

      assert_equal 'CFGA', c.code
      assert_equal 2, c.subunit
      assert_equal 'A', c.symbol

      c = Mint::Currency.for_code('CFGB')

      assert_equal 'CFGB', c.code
      assert_equal 3, c.subunit
      assert_equal 'B', c.symbol
    end
  end

  test 'money can be minted with configured currency' do
    with_money_attribute_config(added_currencies: [
                                   { currency: 'CFGC', subunit: 2, symbol: 'C' }
                                 ]) do
      money = Mint.money(42.50, 'CFGC')

      assert_in_delta(42.50, money.amount)
      assert_equal 'CFGC', money.currency.code
    end
  end

  test 'currencies registered via dummy initializer are available' do
    assert Mint::Currency.for_code('CRCA')
    assert Mint::Currency.for_code('NGNA')
    assert_equal 2, Mint::Currency.for_code('CRCA').subunit
    assert_equal 3, Mint::Currency.for_code('NGNA').subunit
  end

  private

  def with_money_attribute_config(overrides)
    original = {
      added_currencies: MoneyAttribute.config.added_currencies,
      default_currency: MoneyAttribute.config.default_currency,
      default_format: MoneyAttribute.config.default_format
    }

    MoneyAttribute.configure do |config|
      overrides.each { |key, value| config.public_send("#{key}=", value) }
    end

    MoneyAttribute::Railtie.register_custom_currencies!

    yield
  ensure
    MoneyAttribute.configure do |config|
      original.each { |key, value| config.public_send("#{key}=", value) }
    end

    MoneyAttribute::Railtie.register_custom_currencies!
  end
end
