# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module ColumnTypeValidations
    VALID_AMOUNT_TYPES = %i[integer bigint decimal].freeze
    VALID_CURRENCY_TYPES = %i[string text].freeze

    def assert_valid_amount_column!(attr_name, column_name, column)
      return if VALID_AMOUNT_TYPES.include?(column.type)

      raise ArgumentError,
            "`:#{attr_name}` amount column `#{column_name}` must be a numeric type " \
            "(integer, bigint, or decimal), got `#{column.type}`"
    end

    def assert_valid_currency_column!(attr_name, column_name, column)
      return if VALID_CURRENCY_TYPES.include?(column.type)

      raise ArgumentError,
            "`:#{attr_name}` currency column `#{column_name}` must be a string type " \
            "(string or text), got `#{column.type}`"
    end
  end
end
