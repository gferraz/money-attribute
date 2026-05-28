# frozen_string_literal: true

module Mint
  module MoneyAttribute
    class Configuration
      attr_accessor :added_currencies, :enabled_currencies, :default_currency,
                    :rounding_mode, :default_format

      def initialize
        @added_currencies = []
        @enabled_currencies = :all
        @default_currency = 'USD'
        @rounding_mode = nil
        @default_format = nil
      end
    end
  end

  def self.config
    @config ||= MoneyAttribute::Configuration.new
  end

  def self.configure
    yield config if block_given?
    @default_currency = nil
    config
  end

  def self.assert_valid_currency!(currency)
    currency = Mint.currency(currency)
    return currency if config.valid_currency?(currency)

    raise ArgumentError, "Invalid currency '#{currency.code}'. Please select a registered currency"
  end

  def self.default_currency
    @default_currency ||= Mint.assert_valid_currency!(config.default_currency)
  end

  def self.valid_currency?(currency)
    currencies = config.enabled_currencies == :all ? Mint.currencies : config.enabled_currencies
    currencies.include?(currency)
  end
end
