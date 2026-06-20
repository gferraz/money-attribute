# frozen_string_literal: true

module MoneyAttribute
  class Configuration
    attr_accessor :added_currencies, :default_currency,
                  :default_format

    def initialize
      @added_currencies = []
      @default_currency = 'USD'
      @default_format = nil
    end
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config if block_given?
    @default_currency = nil
    config
  end

  def self.default_currency
    @default_currency ||= ::Mint::Currency.resolve!(config.default_currency)
  end
end
