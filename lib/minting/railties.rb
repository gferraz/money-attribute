# frozen_string_literal: true

module Mint
  class Railtie < ::Rails::Railtie
    generators do
      require 'generators/minting/initializer_generator'
    end

    initializer 'minting-rails.i18n' do |app|
      locale_dir = File.expand_path('../../config/locales', __dir__)
      app.config.i18n.load_path += Dir[File.join(locale_dir, '*.yml')]
    end

    config.after_initialize do
      Mint.locale_backend = -> {
        fmt = I18n.t('number.currency.format', default: {})
        {
          decimal: fmt[:separator],
          thousand: fmt[:delimiter],
          format: fmt[:format]&.gsub('%n', '%<amount>f')&.gsub('%u', '%<symbol>s')
        }
      }

      Array(Mint.config.added_currencies).each do |currency_data|
        if currency_data.respond_to?(:values_at)
          code = currency_data[:currency] || currency_data['currency']
          subunit = currency_data[:subunit] || currency_data['subunit']
          symbol = currency_data[:symbol] || currency_data['symbol']
        else
          code, subunit, symbol = *currency_data
        end
        Currency.register(code:, subunit:, symbol:)
      end
    end
  end
end
