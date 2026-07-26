# frozen_string_literal: true

require 'concurrent/map'

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    REGISTRY = Concurrent::Map.new

    class_methods do
      def register_money_attribute_spec(name, kind:, amount_col:, currency_col: nil)
        spec = MoneyAttribute::AttributeSpec.new(
          name: name.to_s,
          kind: kind,
          amount_col: amount_col.to_s,
          currency_col: currency_col&.to_s
        )

        money_attribute_specs[spec.name] = spec
        spec
      end

      def money_attribute_spec(name)
        money_attribute_specs[name.to_s]
      end

      def money_attribute_specs
        REGISTRY.fetch_or_store(self) { {} }
      end
    end
  end
end
