# frozen_string_literal: true

module MoneyAttribute
  module MoneyAmount
    extend ActiveSupport::Concern

    class_methods do
      def money_amount(name, currency: MoneyAttribute.default_currency)
        name = name.to_s

        unless attribute_names.include?(name)
          raise ArgumentError,
                "Column '#{name}' does not exist on this table. " \
                "Add a column named '#{name}' or use a different accessor name."
        end

        currency = ::Mint::Currency.resolve!(currency)

        column_type = if (col = columns.find { |c| c.name == name })
                        %i[integer bigint].include?(col.type) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
                      else
                        ActiveRecord::Type::Decimal.new
                      end

        attribute(name.to_sym, :mint_money, currency:, column_type:)
        normalizes(name.to_sym, with: Converter.new(currency))
      end
    end
  end
end
