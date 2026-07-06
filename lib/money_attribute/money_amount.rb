# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      def money_amount(name, currency: MoneyAttribute.default_currency)
        name = name.to_s

        assert_column_exists!(name)

        currency = ::Mint::Currency.resolve!(currency)
        column_type = detect_column_type(name)

        attribute(name.to_sym, MoneyAttribute::Type.new(currency:, column_type:))
        normalizes(name.to_sym, with: Converter.new(currency))
      end

      private

      def assert_column_exists!(name)
        return if attribute_names.include?(name)

        raise ArgumentError,
              "Column '#{name}' does not exist on this table. " \
              "Add a column named '#{name}' or use a different accessor name."
      end

      def detect_column_type(name)
        col = columns.find { |c| c.name == name }
        %i[integer bigint].include?(col&.type) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
      end
    end
  end
end
