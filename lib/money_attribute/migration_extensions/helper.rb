# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    # :nodoc:
    module Helper
      AMOUNT_CONFIG = {
        crypto_decimal: { type: :decimal, precision: 36, scale: 18 },
        fiat_decimal: { type: :decimal, precision: 20, scale: 4 },
        fiat_integer: { type: :bigint }
      }.freeze

      CURRENCY_MIN_LIMIT = 8
      CURRENCY_DEFAULT_LIMIT = 20

      private

      def parse_money_amount_args(accessor, options)
        options ||= {}
        if options.key?(:precision) || options.key?(:scale)
          raise ArgumentError,
                'precision:/scale: are not configurable — money_attribute uses fixed, ' \
                'vetted values per type (:crypto_decimal, :fiat_decimal, :fiat_integer) ' \
                'to prevent under-precision bugs, particularly for crypto amounts.'
        end

        column = (options[:column] || accessor).to_s

        config = AMOUNT_CONFIG[options[:type] || :fiat_decimal]
        unless config
          raise ArgumentError, "Invalid type #{options[:type]}. Use :crypto_decimal, :fiat_decimal or :fiat_integer"
        end

        options = { null: options[:null], default: options[:default] }.compact
        [column, config.merge(options)]
      end

      def parse_currency_args(accessor, options)
        options ||= {}
        limit = (options[:limit] || CURRENCY_DEFAULT_LIMIT).to_i
        if limit < CURRENCY_MIN_LIMIT
          raise ArgumentError,
                "currency limit: #{limit} is too small to hold an ISO 4217 code and crypto popular codes" \
                "(minimum #{CURRENCY_MIN_LIMIT}). Omit limit: to use the default of #{CURRENCY_DEFAULT_LIMIT}, " \
                "or pass a value >= #{CURRENCY_MIN_LIMIT}."
        end

        column = currency_column_name(accessor, options[:column])
        [column, { limit:, null: options[:null], default: options[:default] }.compact]
      end

      def currency_column_name(accessor, column_override)
        return column_override.to_s if column_override

        name = accessor.to_s
        return 'currency' if name == 'amount'

        radical = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
        "#{radical}_currency"
      end

      def parse_money_args(accessor, options = {})
        amount_column, amount_options = parse_money_amount_args(accessor, options[:amount])
        currency_column, currency_options = parse_currency_args(accessor, options[:currency])

        [amount_column, currency_column, amount_options, currency_options]
      end
    end
  end
end
