# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    # :nodoc:
    module TableDefinition
      include Helper

      def money_attribute(accessor, options = {})
        amount_column, currency_column, amount_opts, currency_opts = parse_money_args(accessor, options)

        column(amount_column, amount_opts[:type], **amount_opts.except(:type))
        column(currency_column, :string, **currency_opts)
      end

      def remove_money_attribute(accessor, options = {})
        amount_column, currency_column, = parse_money_args(accessor, options)

        remove_column(amount_column)
        remove_column(currency_column)
      end

      def money_amount(accessor, options = {})
        amount_column, amount_opts = parse_money_amount_args(accessor, options)

        column(amount_column, amount_opts[:type], **amount_opts.except(:type))
      end

      def remove_money_amount(accessor, options = {})
        amount_column, = parse_money_amount_args(accessor, options)

        remove_column(amount_column)
      end
    end
  end
end
