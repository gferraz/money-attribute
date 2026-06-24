# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    module SchemaStatements
      include Helper

      def add_money_attribute(table_name, accessor, options = {})
        amount_col, currency_col, amount_opts, currency_opts = parse_money_args(accessor, options)

        add_column(table_name, amount_col, amount_opts[:type], **amount_opts.except(:type))
        add_column(table_name, currency_col, :string, **currency_opts) if currency_col
      end

      def remove_money_attribute(table_name, accessor, options = {})
        amount_col, currency_col, = parse_money_args(accessor, options)

        remove_column(table_name, amount_col)
        remove_column(table_name, currency_col) if currency_col
      end
    end
  end
end
