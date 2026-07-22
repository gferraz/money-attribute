# frozen_string_literal: true

module MoneyAttribute
  class Configuration
    attr_accessor :added_currencies, :default_currency

    def initialize
      @added_currencies = []
      @default_currency = 'USD'
    end
  end

  cfg = Configuration.new
  cached_default = nil

  define_singleton_method(:config) { cfg }

  define_singleton_method(:configure) do |&block|
    block&.call(cfg)
    cached_default = nil
    cfg
  end

  define_singleton_method(:default_currency) do
    cached_default ||= ::Mint::Currency.resolve!(cfg.default_currency)
  end
end
