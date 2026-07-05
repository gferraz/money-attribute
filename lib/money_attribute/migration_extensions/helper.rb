# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    module Helper
      private

      AMOUNT_CONFIG = {
        crypto_decimal: { type: :decimal, precision: 36, scale: 18 },
        fiat_decimal:   { type: :decimal, precision: 20, scale: 4 },
        fiat_integer:   { type: :bigint }
      }.freeze

      CURRENCY_LIMIT_RANGE = 4..32

      def parse_money_amount_args(accessor, options)
        options ||= {}
        column = (options[:column] || accessor).to_s

        config = AMOUNT_CONFIG[options[:type] || :fiat_decimal]
        unless config
          raise ArgumentError, "Invalid money amount type #{options[:type]}. Use :crypto_decimal, :fiat_decimal or :fiat_integer"
        end

        options = { null: options[:null], default: options[:default] }.compact
        [column, config.merge(options)]
      end

      def parse_currency_args(accessor, options)
        options ||= {}
        column = options[:column]&.to_s
        unless column
          name = accessor.to_s
          if name == 'amount'
            column = 'currency'
          else
            radical = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
            column = "#{radical}_currency"
          end
        end
          limit = (options[:limit] || 16).to_i.clamp(CURRENCY_LIMIT_RANGE)
        [column, { limit: limit, null: options[:null], default: options[:default] }.compact]
      end

      def parse_money_args(accessor, options = {})
        amount_column, amount_options = parse_money_amount_args(accessor, options[:amount])
        currency_column, currency_options = parse_currency_args(accessor, options[:currency])

        return [amount_column, currency_column, amount_options, currency_options]
      end
    end
  end
end
