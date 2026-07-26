# frozen_string_literal: true

module MoneyAttribute
  # Shared helpers for money attribute query modules.
  module QueryHelpers
    def money_attribute_spec!(attr)
      spec = klass.money_attribute_spec(attr)
      return spec if spec

      raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
    end
  end
end
