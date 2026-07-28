# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      # Declares a fixed-currency money attribute backed by a single column.
      def money_amount(name)
        name = name.to_s

        assert_column_exists!(name)

        column_type = detect_column_type(name)
        amount_type = integer_column?(name) ? :integer : :decimal

        attribute(name.to_sym, MoneyAttribute::Type.new(column_type:))
        normalizes(name.to_sym, with: Converter.default)
        register_money_attribute_spec(name, kind: :single, amount_col: name, amount_type: amount_type)
      end

      private

      # Raises if the column does not exist on the model.
      def assert_column_exists!(name)
        return if attribute_method?(name)

        raise ArgumentError,
              "Column '#{name}' does not exist on this table. " \
              "Add a column named '#{name}' or use a different accessor name."
      end

      # Returns the Active Record type object for the backing column.
      def detect_column_type(name)
        integer_column?(name) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
      end
    end
  end
end
