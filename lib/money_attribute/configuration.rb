# frozen_string_literal: true

module MoneyAttribute
  CONFIG_MUTEX = Mutex.new

  class << self
    # Returns the lazily initialized gem configuration.
    def config
      CONFIG_MUTEX.synchronize { @config ||= Config.new }
    end

    # Yields the current configuration object for mutation.
    def configure = yield config

    # Returns the current request or default currency as a resolved currency.
    # Memoized per-thread — within a request, Current.currency is stable.
    def default_currency
      code = MoneyAttribute::Current.currency.presence || config.default_currency

      last_code, last_currency = Thread.current[:money_attribute_default_currency]
      return last_currency if last_code == code

      currency = Money::Currency.resolve!(code)
      Thread.current[:money_attribute_default_currency] = [code, currency]
      currency
    end
  end

  class Config
    attr_accessor :default_currency, :added_currencies

    # Initializes the default gem configuration values.
    def initialize
      @default_currency = 'USD'
      @added_currencies = []
    end
  end
end
