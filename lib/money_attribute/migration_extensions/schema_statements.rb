# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    # Migration helper methods for +ActiveRecord::Migration+.
    #
    # Provides reversible methods to add and remove money attribute columns
    # from within a +change+ migration block.
    #
    # @example Adding a composite money attribute
    #   class AddPriceToProducts < ActiveRecord::Migration[8.0]
    #     def change
    #       add_money_attribute :products, :price
    #     end
    #   end
    #
    # @example Adding a single-column money amount
    #   class AddDiscountToProducts < ActiveRecord::Migration[8.0]
    #     def change
    #       add_money_amount :products, :discount, type: :fiat_integer
    #     end
    #   end
    module SchemaStatements
      include Helper

      # Adds an amount column and a currency column for a composite money attribute.
      #
      # The amount column type is determined by the +:type+ option inside
      # +amount: { type: }+ (defaults to +:fiat_decimal+). The currency column
      # is a string with a configurable limit.
      #
      # @param table_name [Symbol, String] the table to alter
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] migration options
      # @option options [Hash] :amount amount column options
      #   (+:column+, +:type+, +:null+, +:default+)
      # @option options [Hash] :currency currency column options
      #   (+:column+, +:limit+, +:null+, +:default+)
      # @return [void]
      #
      # @example Default naming and type
      #   add_money_attribute :products, :price
      #   # => add_column :products, :price, :decimal, precision: 20, scale: 4
      #   # => add_column :products, :price_currency, :string, limit: 20
      #
      # @example Custom columns and integer type
      #   add_money_attribute :products, :price,
      #     amount: { column: :base_price, type: :fiat_integer },
      #     currency: { column: :base_currency, limit: 3 }
      def add_money_attribute(table_name, accessor, options = {})
        amount_column, currency_column, amount_opts, currency_opts = parse_money_args(accessor, options)

        type = amount_opts.delete(:type)
        add_column(table_name, amount_column, type, **amount_opts)
        add_column(table_name, currency_column, :string, **currency_opts)
      end

      # Removes the amount and currency columns for a composite money attribute.
      #
      # Accepts the same +:amount+ and +:currency+ options as
      # {#add_money_attribute} to identify the columns.
      #
      # @param table_name [Symbol, String] the table to alter
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] migration options
      # @option options [Hash] :amount amount column options (+:column+)
      # @option options [Hash] :currency currency column options (+:column+)
      # @return [void]
      def remove_money_attribute(table_name, accessor, options = {})
        amount_column, currency_column, = parse_money_args(accessor, options)

        remove_column(table_name, amount_column)
        remove_column(table_name, currency_column)
      end

      # Adds a single amount column for a fixed-currency money attribute.
      #
      # No currency column is created — the application default currency is
      # used for all rows.
      #
      # @param table_name [Symbol, String] the table to alter
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] column options
      # @option options [Symbol] :column explicit column name override
      # @option options [Symbol] :type amount type (+:fiat_decimal+,
      #   +:crypto_decimal+, +:fiat_integer+)
      # @option options [Boolean] :null whether the column allows NULL
      # @option options [Object] :default default value for the column
      # @return [void]
      #
      # @example Default naming and type
      #   add_money_amount :products, :discount
      #   # => add_column :products, :discount, :decimal, precision: 20, scale: 4
      #
      # @example Integer column with explicit name
      #   add_money_amount :products, :bonus, column: :bonus_cents, type: :fiat_integer
      def add_money_amount(table_name, accessor, options = {})
        amount_column, amount_opts = parse_money_amount_args(accessor, options)

        type = amount_opts.delete(:type)
        add_column(table_name, amount_column, type, **amount_opts)
      end

      # Removes the amount column for a fixed-currency money attribute.
      #
      # @param table_name [Symbol, String] the table to alter
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] column options
      # @option options [Symbol] :column explicit column name override
      # @return [void]
      def remove_money_amount(table_name, accessor, options = {})
        remove_column(table_name, (options[:column] || accessor).to_s)
      end
    end
  end
end
