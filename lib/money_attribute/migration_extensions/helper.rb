# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    module Helper
      private

      def parse_money_args(accessor, options = {})
        name = accessor.to_s

        amount_col, amount_opts = resolve_amount_column(name, options)

        stripped = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
        default_currency_col = if name == 'amount' && !(options[:currency].is_a?(Hash) && options[:currency][:column])
                                 'currency'
                               else
                                 "#{stripped}_currency"
                               end

        if options.key?(:currency) && options[:currency].is_a?(Hash)
          opts = options[:currency]
          currency_col = opts[:column]&.to_s || default_currency_col
          currency_opts = { limit: opts[:limit], null: opts[:null], default: opts[:default] }.compact
        else
          currency_col = default_currency_col
          currency_opts = {}
        end

        [amount_col, currency_col, amount_opts, currency_opts]
      end

      def parse_money_amount_args(accessor, options = {})
        name = accessor.to_s
        amount_col, amount_opts = resolve_amount_column(name, options)

        [amount_col, amount_opts]
      end

      def resolve_amount_column(name, options)
        if options.key?(:amount) && options[:amount].is_a?(Hash)
          opts = options[:amount]
          col = opts[:column]&.to_s || name
          amount_opts = { type: opts[:type], null: opts[:null], default: opts[:default],
                          precision: opts[:precision], scale: opts[:scale] }.compact
        else
          col = name
          amount_opts = {}
        end

        amount_opts[:type] ||= :decimal

        if amount_opts[:type] == :decimal && !amount_opts.key?(:precision) && !amount_opts.key?(:scale)
          amount_opts[:precision] = 16
          amount_opts[:scale]     = 4
        elsif amount_opts[:type] != :decimal
          amount_opts.delete(:precision)
          amount_opts.delete(:scale)
        end

        [col, amount_opts]
      end
    end
  end
end
