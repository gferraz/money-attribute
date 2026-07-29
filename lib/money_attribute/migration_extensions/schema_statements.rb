# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    # :nodoc:
    module SchemaStatements
      include Helper

      def add_money_attribute(table_name, accessor, options = {})
        amount_column, currency_column, amount_opts, currency_opts = parse_money_args(accessor, options)

        type = amount_opts.delete(:type)
        add_column(table_name, amount_column, type, **amount_opts)
        add_column(table_name, currency_column, :string, **currency_opts)
      end

      def remove_money_attribute(table_name, accessor, options = {})
        amount_column, currency_column, = parse_money_args(accessor, options)

        remove_column(table_name, amount_column)
        remove_column(table_name, currency_column)
      end

      def add_money_amount(table_name, accessor, options = {})
        amount_column, amount_opts = parse_money_amount_args(accessor, options)

        type = amount_opts.delete(:type)
        add_column(table_name, amount_column, type, **amount_opts)
      end

      def remove_money_amount(table_name, accessor, options = {})
        remove_column(table_name, (options[:column] || accessor).to_s)
      end
    end
  end
end
