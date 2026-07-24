# frozen_string_literal: true

module MoneyAttribute
  CONFIG_MUTEX = Mutex.new

  class << self
    def config
      CONFIG_MUTEX.synchronize { @config ||= Config.new }
    end

    def configure = yield config

    def default_currency
      currency = MoneyAttribute::Current.currency.presence || config.default_currency
      Money::Currency.resolve!(currency)
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
