# frozen_string_literal: true

module MoneyAttribute
  module MigrationExtensions
    module Helper
      private

      def parse_money_args(accessor, options = {})
        name = accessor.to_s

        amount_col = options.key?(:amount) ? options[:amount].to_s : name

        if options.key?(:currency)
          currency_col = if options[:currency] == false
                           nil
                         else
                           options[:currency].to_s
                         end
        else
          stripped = name.end_with?('_amount') ? name.sub(/_amount$/, '') : name
          currency_col = "#{stripped}_currency"
        end

        col_type = options[:type] || :decimal

        amount_opts = {}
        amount_opts[:type] = col_type

        if options.key?(:amount) && options[:amount].is_a?(Hash)
          amount_opts[:null]      = options[:amount][:null]      if options[:amount].key?(:null)
          amount_opts[:default]   = options[:amount][:default]   if options[:amount].key?(:default)
          amount_opts[:precision] = options[:amount][:precision] if options[:amount].key?(:precision)
          amount_opts[:scale]     = options[:amount][:scale]     if options[:amount].key?(:scale)
        end

        if col_type == :decimal && !amount_opts.key?(:precision) && !amount_opts.key?(:scale)
          amount_opts[:precision] = 16
          amount_opts[:scale]     = 4
        end

        currency_opts = {}
        currency_opts[:limit] = options[:currency_limit] if options[:currency_limit]

        if options[:currency].is_a?(Hash)
          currency_opts[:null]    = options[:currency][:null]    if options[:currency].key?(:null)
          currency_opts[:default] = options[:currency][:default] if options[:currency].key?(:default)
        end

        [amount_col, currency_col, amount_opts, currency_opts]
      end
    end
  end
end
