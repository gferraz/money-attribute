# frozen_string_literal: true

module MoneyAttribute
  # Declares fixed-currency money attributes on Active Record models.
  #
  # Provides the +money_amount+ class method which wires a single backing
  # column to a +Mint::Money+ value object using a custom attribute type and a
  # normalizer. The application default currency (or {Current} per-request
  # override) applies to all rows.
  #
  # @example
  #   class SimpleOffer < ApplicationRecord
  #     money_amount :price
  #   end
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      include ColumnTypeValidations

      # Declares a fixed-currency money attribute backed by a single column.
      #
      # The column type determines the storage unit: integer/bigint stores
      # subunits, decimal stores the unit value. No currency column is created —
      # the application default currency applies to every row.
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @return [void]
      # @raise [ArgumentError] if the column does not exist or has an
      #   unsupported type
      #
      # @example
      #   class SimpleOffer < ApplicationRecord
      #     money_amount :price
      #   end
      def money_amount(name)
        column = column_for_attribute(name)

        unless column
          raise ArgumentError,
                "Column '#{name}' does not exist on this table. " \
                "Add a column named '#{name}' or use a different accessor name."
        end

        assert_valid_amount_column!(name, name, column)

        if %i[integer bigint].include?(column.type)
          amount_type = :integer
          type_class = IntegerAmountType
        else
          amount_type = :decimal
          type_class = DecimalAmountType
        end

        attribute(name, type_class.new)
        normalizes(name, with: Converter.default)
        register_money_attribute_spec(name, kind: :single, amount_column: name, amount_type: amount_type)
      end
    end
  end
end
