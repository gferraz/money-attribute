# frozen_string_literal: true

module MoneyAttribute
  # @private
  CONFIG_MUTEX = Mutex.new

  class << self
    # Returns the lazily initialized gem configuration.
    #
    # @return [Config]
    def config
      CONFIG_MUTEX.synchronize { @config ||= Config.new }
    end

    # Yields the current configuration object for mutation.
    #
    # @yield [config] the current configuration
    # @return [void]
    def configure = yield config

    # Returns the current request or default currency as a resolved currency.
    # Memoized per-thread — within a request, Current.currency is stable.
    #
    # @return [Mint::Currency]
    def default_currency
      code = MoneyAttribute::Current.currency.presence || config.default_currency

      last_code, last_currency = Thread.current[:money_attribute_default_currency]
      return last_currency if last_code == code

      currency = Money::Currency.resolve!(code)
      Thread.current[:money_attribute_default_currency] = [code, currency]
      currency
    end
  end

  # Gem configuration holding the default currency and registered custom currencies.
  #
  #   MoneyAttribute.configure do |config|
  #     config.default_currency = 'BRL'
  #   end
  class Config
    # @return [String] ISO 4217 currency code used when no per-request or per-row currency is set.
    attr_accessor :default_currency

    # @return [Array<Hash>] custom currencies registered via +register_custom_currencies!+.
    attr_accessor :added_currencies

    # Initializes the default gem configuration values.
    def initialize
      @default_currency = 'USD'
      @added_currencies = []
    end
  end
end
