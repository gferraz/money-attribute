# frozen_string_literal: true

module MoneyAttribute
  # Rails engine integration.
  #
  # On boot, includes the migration and form-builder extensions into the
  # corresponding Rails classes, wires Mint's locale backend to Rails i18n,
  # and registers custom currencies declared in the initializer.
  #
  # @example Generated initializer
  #   MoneyAttribute.configure do |config|
  #     config.default_currency = 'BRL'
  #     config.added_currencies = [
  #       { currency: 'BTB', subunit: 8, symbol: '₿' }
  #     ]
  #   end
  #
  # @api private
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

    # Configures Mint to use the Rails locale currency format.
    #
    # @return [void]
    # @api private
    def self.setup_locale_backend!
      ::Mint.locale_backend = method(:build_locale_format).to_proc
    end

    # Builds the locale-aware currency formatting hash.
    #
    # @return [Hash] the +:decimal+, +:thousand+, and +:format+ keys for Mint
    # @api private
    def self.build_locale_format
      fmt = I18n.t('number.currency.format', default: {})
      { decimal: fmt[:separator], thousand: fmt[:delimiter], format: build_format(fmt) }
    end

    # Builds the final currency format string or hash for Mint.
    #
    # @param fmt [Hash] the Rails currency format settings
    # @return [String, Hash] a single format string or a per-sign format hash
    # @api private
    def self.build_format(fmt)
      if %i[positive negative zero].any? { |k| fmt.key?(k) }
        build_hash_format(fmt)
      else
        translate_format(fmt[:format])
      end
    end

    # Builds a per-sign currency format hash.
    #
    # @param fmt [Hash] the Rails currency format settings
    # @return [Hash] the +:positive+, +:negative+, and +:zero+ format strings
    # @api private
    def self.build_hash_format(fmt)
      {
        positive: translate_format(fmt[:positive] || fmt[:format]),
        negative: translate_format(fmt[:negative] || fmt[:format]),
        zero: translate_format(fmt[:zero] || fmt[:format])
      }
    end

    # Translates Rails currency placeholders into Mint placeholders.
    #
    # @param str [String, nil] the Rails format string
    # @return [String] the translated format string
    # @api private
    def self.translate_format(str)
      str.to_s.gsub('%n', '%<amount>f').gsub('%u', '%<symbol>s')
    end

    # Registers custom currencies configured by the application.
    #
    # Accepts hashes with +:currency+, +:subunit+, +:symbol+ keys or the
    # matching positional array form. Already-registered currencies are skipped.
    #
    # @return [void]
    # @raise [ArgumentError] if a currency hash is missing a required key
    # @api private
    def self.register_custom_currencies!
      Array(MoneyAttribute.config.added_currencies).each do |currency_data|
        if currency_data.respond_to?(:values_at)
          code = currency_data[:currency]
          subunit = currency_data[:subunit]
          symbol = currency_data[:symbol]
        else
          code, subunit, symbol = *currency_data
        end
        Money::Currency.register(code:, subunit:, symbol:)
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
