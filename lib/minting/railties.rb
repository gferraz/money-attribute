# frozen_string_literal: true

module Mint
  class Railtie < ::Rails::Railtie
    generators do
      require 'generators/minting/initializer_generator'
    end

    config.to_prepare do
      Array(Mint.config.added_currencies).each do |currency_data|
        if currency_data.respond_to?(:values_at)
          code = currency_data[:currency] || currency_data['currency']
          subunit = currency_data[:subunit] || currency_data['subunit']
          symbol = currency_data[:symbol] || currency_data['symbol']
        else
          code, subunit, symbol = *currency_data
        end
        Mint.register_currency(code:, subunit:, symbol:) 
      end
    end
  end
end
