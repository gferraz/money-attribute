# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    # :nodoc:
    module TableDefinition
      include Helper

      def money_attribute(accessor, options = {})
        amount_col, currency_col, amount_opts, currency_opts = parse_money_args(accessor, options)

        column(amount_col, amount_opts[:type], **amount_opts.except(:type))
        column(currency_col, :string, **currency_opts)
      end

      def remove_money_attribute(accessor, options = {})
        amount_col, currency_col, = parse_money_args(accessor, options)

        remove_column(amount_col)
        remove_column(currency_col)
      end

      def money_amount(accessor, options = {})
        amount_col, amount_opts = parse_money_amount_args(accessor, options)

        column(amount_col, amount_opts[:type], **amount_opts.except(:type))
      end

      def remove_money_amount(accessor, options = {})
        amount_col, = parse_money_amount_args(accessor, options)

        remove_column(amount_col)
      end
    end
  end
end
