# frozen_string_literal: true

require_relative 'helper'

module MoneyAttribute
  module MigrationExtensions
    # Migration DSL methods for use inside +create_table+ and +change_table+
    # blocks.
    #
    # Included into both +ActiveRecord::ConnectionAdapters::TableDefinition+
    # and +ActiveRecord::ConnectionAdapters::Table+.
    #
    # @example Inside a +create_table+ block
    #   create_table :products do |t|
    #     t.string :name
    #     t.money_attribute :price
    #     t.money_amount :discount, type: :fiat_integer
    #   end
    #
    # @example Inside a +change_table+ block
    #   change_table :products do |t|
    #     t.money_attribute :price, amount: { type: :fiat_integer }
    #     t.remove_money_attribute :old_price
    #   end
    module TableDefinition
      include Helper

      # Adds amount and currency columns within a table definition.
      #
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] migration options
      # @option options [Hash] :amount amount column options
      #   (+:column+, +:type+, +:null+, +:default+)
      # @option options [Hash] :currency currency column options
      #   (+:column+, +:limit+, +:null+, +:default+)
      # @return [void]
      #
      # @example
      #   t.money_attribute :price
      #   t.money_attribute :price, amount: { type: :fiat_integer }
      def money_attribute(accessor, options = {})
        amount_column, currency_column, amount_opts, currency_opts = parse_money_args(accessor, options)

        column(amount_column, amount_opts[:type], **amount_opts.except(:type))
        column(currency_column, :string, **currency_opts)
      end

      # Removes amount and currency columns within a table definition.
      #
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] migration options
      # @option options [Hash] :amount amount column options (+:column+)
      # @option options [Hash] :currency currency column options (+:column+)
      # @return [void]
      def remove_money_attribute(accessor, options = {})
        amount_column, currency_column, = parse_money_args(accessor, options)

        remove_column(amount_column)
        remove_column(currency_column)
      end

      # Adds a single amount column within a table definition.
      #
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] column options
      # @option options [Symbol] :column explicit column name override
      # @option options [Symbol] :type amount type (+:fiat_decimal+,
      #   +:crypto_decimal+, +:fiat_integer+)
      # @option options [Boolean] :null whether the column allows NULL
      # @option options [Object] :default default value for the column
      # @return [void]
      #
      # @example
      #   t.money_amount :discount
      #   t.money_amount :bonus, column: :bonus_cents, type: :fiat_integer
      def money_amount(accessor, options = {})
        amount_column, amount_opts = parse_money_amount_args(accessor, options)

        column(amount_column, amount_opts[:type], **amount_opts.except(:type))
      end

      # Removes a single amount column within a table definition.
      #
      # @param accessor [Symbol, String] the money attribute accessor name
      # @param options [Hash] column options
      # @option options [Symbol] :column explicit column name override
      # @return [void]
      def remove_money_amount(accessor, options = {})
        amount_column, = parse_money_amount_args(accessor, options)

        remove_column(amount_column)
      end
    end
  end
end
