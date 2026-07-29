# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      include ColumnTypeValidations

      # Declares a fixed-currency money attribute backed by a single column.
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
        register_money_attribute_spec(name, kind: :single, amount_col: name, amount_type: amount_type)
      end
    end
  end
end
