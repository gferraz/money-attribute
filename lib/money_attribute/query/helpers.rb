# frozen_string_literal: true

module MoneyAttribute
  # Shared helpers for money attribute query modules.
  module QueryHelpers
    def money_amount_attribute?(attr)
      type = klass.type_for_attribute(attr)
      type.respond_to?(:cast_type) && type.cast_type.is_a?(MoneyAttribute::Type)
    end

    def validate_currency_match!(first, second)
      return if first.currency_code == second.currency_code

      raise ArgumentError,
            "Currency mismatch in range: #{first.currency_code} != #{second.currency_code}"
    end
  end
end
