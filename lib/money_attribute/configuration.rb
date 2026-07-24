# frozen_string_literal: true

module MoneyAttribute
  CONFIG_MUTEX = Mutex.new

  class << self
    def config
      CONFIG_MUTEX.synchronize { @config ||= Config.new }
    end

    def configure
      yield config
    end

    def default_currency
      if defined?(MoneyAttribute::Current) && MoneyAttribute::Current.currency.present?
        ::Mint::Currency.resolve!(MoneyAttribute::Current.currency)
      else
        ::Mint::Currency.resolve!(config.default_currency)
      end
    end
  end

  class Config
    attr_accessor :default_currency, :added_currencies

    def initialize
      @default_currency = 'USD'
      @added_currencies = []
    end
  end
end
