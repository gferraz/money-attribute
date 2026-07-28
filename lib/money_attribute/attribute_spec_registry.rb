# frozen_string_literal: true

require 'concurrent/map'

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    REGISTRY = Concurrent::Map.new

    class_methods do
      # Registers a money attribute spec for the current model class.
      #
      # @param name [Symbol, String] the attribute name
      # @param kind [Symbol] +:composite+ or +:single+
      # @param amount_col [Symbol, String] the amount column name
      # @param currency_col [Symbol, String, nil] the currency column name (composite only)
      # @param amount_type [Symbol, nil] +:integer+ or +:decimal+
      # @return [AttributeSpec]
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
      #
      # @param name [Symbol, String] the attribute name
      # @return [AttributeSpec, nil]
      def money_attribute_spec(name)
        REGISTRY[self]&.fetch(name.to_s, nil)
      end

      # Returns the registry hash for the current model class.
      #
      # @return [Hash{String => AttributeSpec}]
      def money_attribute_specs
        REGISTRY.fetch_or_store(self) { {} }
      end
    end
  end
end
