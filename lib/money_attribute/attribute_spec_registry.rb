# frozen_string_literal: true

require 'concurrent/map'

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    REGISTRY = Concurrent::Map.new

    class_methods do
      # Registers a money attribute spec for the current model class.
      def register_money_attribute_spec(name, kind:, amount_col:, currency_col: nil, amount_type: nil)
        spec = MoneyAttribute::AttributeSpec.new(
          name: name.to_s,
          kind: kind,
          amount_col: amount_col.to_s,
          currency_col: currency_col&.to_s,
          amount_type: amount_type
        )

        money_attribute_specs[spec.name] = spec
        spec
      end

      # Returns the registered money attribute spec for the given name.
      def money_attribute_spec(name)
        money_attribute_specs[name.to_s]
      end

      # Returns the registry hash for the current model class.
      def money_attribute_specs
        REGISTRY.fetch_or_store(self) { {} }
      end
    end
  end
end
