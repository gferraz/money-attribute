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
    def default_currency
      currency = MoneyAttribute::Current.currency.presence || config.default_currency
      Money::Currency.resolve!(currency)
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
