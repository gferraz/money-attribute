# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      def money_amount(name)
        name = name.to_s

        assert_column_exists!(name)

        column_type = detect_column_type(name)
        amount_type = integer_column?(name) ? :integer : :decimal

        attribute(name.to_sym, MoneyAttribute::Type.new(column_type:))
        normalizes(name.to_sym, with: Converter.new)
        register_money_attribute_spec(name, kind: :single, amount_col: name, amount_type: amount_type)
      end

      private

      def assert_column_exists!(name)
        return if attribute_names.include?(name)

        raise ArgumentError,
              "Column '#{name}' does not exist on this table. " \
              "Add a column named '#{name}' or use a different accessor name."
      end

      def detect_column_type(name)
        integer_column?(name) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
      end

      def integer_column?(column_name)
        col = columns.find { |c| c.name == column_name }
        %i[integer bigint].include?(col&.type)
      end
    end
  end
end
