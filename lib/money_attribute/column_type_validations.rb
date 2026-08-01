# frozen_string_literal: true

module MoneyAttribute
  # Shared column-type validation for the +money_attribute+ and +money_amount+
  # macros.
  #
  # Included by {Macro::CompositeClassMethods} and {MoneyAmount}. Raises when a
  # backing column uses a type that cannot store a money amount or currency code.
  #
  # @api private
  module ColumnTypeValidations
    VALID_AMOUNT_TYPES = %i[integer bigint decimal].freeze
    VALID_CURRENCY_TYPES = %i[string text].freeze

    # Validates that a column can store a money amount.
    #
    # @param attr_name [Symbol, String] the money attribute accessor name
    # @param column_name [Symbol, String] the amount column name
    # @param column [ActiveRecord::ConnectionAdapters::Column] the column metadata
    # @return [void]
    # @raise [ArgumentError] if the column type is not numeric
    # @api private
    def assert_valid_amount_column!(attr_name, column_name, column)
      return if VALID_AMOUNT_TYPES.include?(column.type)

      raise ArgumentError,
            "`:#{attr_name}` amount column `#{column_name}` must be a numeric type " \
            "(integer, bigint, or decimal), got `#{column.type}`"
    end

    # Validates that a column can store a currency code.
    #
    # @param attr_name [Symbol, String] the money attribute accessor name
    # @param column_name [Symbol, String] the currency column name
    # @param column [ActiveRecord::ConnectionAdapters::Column] the column metadata
    # @return [void]
    # @raise [ArgumentError] if the column type is not string-like
    # @api private
    def assert_valid_currency_column!(attr_name, column_name, column)
      return if VALID_CURRENCY_TYPES.include?(column.type)

      raise ArgumentError,
            "`:#{attr_name}` currency column `#{column_name}` must be a string type " \
            "(string or text), got `#{column.type}`"
    end
  end
end
