# frozen_string_literal: true

module Mint
  module MoneyAttribute
    class Configuration
      attr_accessor :added_currencies, :default_currency,
                    :rounding_mode, :default_format

      def initialize
        @added_currencies = []
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

  def self.default_currency
    @default_currency ||= Currency.resolve!(config.default_currency)
  end
end
