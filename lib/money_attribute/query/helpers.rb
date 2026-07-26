# frozen_string_literal: true

module MoneyAttribute
  # Shared helpers for money attribute query modules.
  module QueryHelpers
    def money_attribute_spec!(attr)
      spec = klass.money_attribute_spec(attr)
      raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}" unless spec

      spec
    end
  end
end
