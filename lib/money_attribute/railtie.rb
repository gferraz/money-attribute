# frozen_string_literal: true

module MoneyAttribute
  class Railtie < ::Rails::Railtie
    generators do
      require 'generators/money_attribute/initializer_generator'
    end

    config.after_initialize do
      require 'money_attribute/migration_extensions/schema_statements'
      require 'money_attribute/migration_extensions/table_definition'

      ActiveRecord::Migration.include(MoneyAttribute::MigrationExtensions::SchemaStatements)
      ActiveRecord::ConnectionAdapters::TableDefinition.include(MoneyAttribute::MigrationExtensions::TableDefinition)
      ActiveRecord::ConnectionAdapters::Table.include(MoneyAttribute::MigrationExtensions::TableDefinition)

      ActionView::Helpers::FormBuilder.include(MoneyAttribute::FormBuilderExtension)

      setup_locale_backend!
      register_custom_currencies!
    end

    def self.setup_locale_backend!
      ::Mint.locale_backend = lambda {
        fmt = I18n.t('number.currency.format', default: {})
        translator = ->(s) { s&.gsub('%n', '%<amount>f')&.gsub('%u', '%<symbol>s') }

        format = if fmt.key?(:positive) || fmt.key?(:negative) || fmt.key?(:zero)
                   {
                     positive: translator.call(fmt[:positive] || fmt[:format]),
                     negative: translator.call(fmt[:negative] || fmt[:format]),
                     zero: translator.call(fmt[:zero] || fmt[:format])
                   }
                 else
                   translator.call(fmt[:format])
                 end

        { decimal: fmt[:separator], thousand: fmt[:delimiter], format: format }
      }
    end

    def self.register_custom_currencies!
      Array(MoneyAttribute.config.added_currencies).each do |currency_data|
        if currency_data.respond_to?(:values_at)
          code = currency_data[:currency]
          subunit = currency_data[:subunit]
          symbol = currency_data[:symbol]
        else
          code, subunit, symbol = *currency_data
        end
        ::Mint::Currency.register(code:, subunit:, symbol:)
      rescue KeyError => e
        unless e.message.include?('already registered')
          raise ArgumentError,
                "Invalid currency configuration: #{currency_data.inspect}. " \
                "Each currency must have :currency, :subunit, and :symbol keys. Error: #{e.message}"
        end
      end
    end
  end
end
