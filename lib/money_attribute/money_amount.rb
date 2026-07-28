# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      # Declares a fixed-currency money attribute backed by a single column.
      def money_amount(name)
        column = column_for_attribute(name)

        unless column
          raise ArgumentError,
                "Column '#{name}' does not exist on this table. " \
                "Add a column named '#{name}' or use a different accessor name."
        end

        amount_type = %i[integer bigint].include?(column.type) ? :integer : :decimal

        attribute(name, MoneyAttribute::Type.new(column_type: amount_type))
        normalizes(name, with: Converter.default)
        register_money_attribute_spec(name, kind: :single, amount_col: name, amount_type: amount_type)
      end
    end
  end
end
