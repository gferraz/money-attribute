# frozen_string_literal: true

module MoneyAttribute
  # Shared helpers for money attribute query modules.
  module QueryHelpers
    MoneyAttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, keyword_init: true) do
      def composite?
        kind == :composite
      end

      def single?
        kind == :single
      end

      def columns
        composite? ? [amount_col, currency_col] : [amount_col]
      end
    end

    def money_amount_attribute?(attr)
      type = klass.type_for_attribute(attr)
      type.respond_to?(:cast_type) && type.cast_type.is_a?(MoneyAttribute::Type)
    end

    def money_attribute_spec(attr)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        amount_col, currency_col = reflection.mapping.keys
        MoneyAttributeSpec.new(name: attr, kind: :composite, amount_col: amount_col, currency_col: currency_col)
      elsif money_amount_attribute?(attr)
        MoneyAttributeSpec.new(name: attr, kind: :single, amount_col: attr)
      end
    end

    def money_attribute_spec!(attr)
      spec = money_attribute_spec(attr)
      return spec if spec

      raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
    end

    def build_money_value(raw_amount, currency, column)
      return raw_amount if raw_amount.is_a?(Mint::Money)
      return nil if raw_amount.nil?

      resolved = Money::Currency.resolve(currency)
      if klass.integer_column?(column)
        Mint::Money.from_subunits(raw_amount, resolved)
      else
        Mint::Money.from(raw_amount, resolved)
      end
    end

    def validate_currency_match!(first, second)
      return if first.currency_code == second.currency_code

      raise ArgumentError,
            "Currency mismatch in range: #{first.currency_code} != #{second.currency_code}"
    end
  end
end
