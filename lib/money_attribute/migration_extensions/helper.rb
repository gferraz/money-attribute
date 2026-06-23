# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    module Helper
      private

      def parse_money_args(accessor, options = {})
        name = accessor.to_s

        if options.key?(:amount) && options[:amount].is_a?(Hash)
          amount_col = options[:amount][:column]&.to_s || name
          opts = options[:amount]
          amount_opts = {
            type: opts[:type],
            null: opts[:null],
            default: opts[:default],
            precision: opts[:precision],
            scale: opts[:scale]
          }.compact
        else
          amount_col = name
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

        stripped = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
        default_currency_col = "#{stripped}_currency"

        if options.key?(:currency) && options[:currency].is_a?(Hash)
          currency_col = options[:currency][:column]&.to_s || default_currency_col
          opts = options[:currency]
          currency_opts = {
            limit: opts[:limit],
            null: opts[:null],
            default: opts[:default]
          }.compact
        elsif options[:currency] == false
          currency_col = nil
          currency_opts = {}
        else
          currency_col = default_currency_col
          currency_opts = {}
        end

        [amount_col, currency_col, amount_opts, currency_opts]
      end
    end
  end
end
