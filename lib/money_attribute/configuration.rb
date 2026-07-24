# frozen_string_literal: true

require 'active_support/configurable'

module MoneyAttribute
  include ActiveSupport::Configurable

  config_accessor :default_currency, default: 'USD'
  config_accessor :added_currencies, default: []

  def self.default_currency
    if defined?(MoneyAttribute::Current) && MoneyAttribute::Current.currency.present?
      ::Mint::Currency.resolve!(MoneyAttribute::Current.currency)
    else
      ::Mint::Currency.resolve!(config.default_currency)
    end
  end
end
