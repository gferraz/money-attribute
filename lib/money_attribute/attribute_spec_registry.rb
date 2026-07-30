# frozen_string_literal: true

require 'concurrent/map'

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    REGISTRY = Concurrent::Map.new
    PATTERNS = Concurrent::Map.new

    class_methods do
      # Registers a money attribute spec for the current model class.
      #
      # @param name [Symbol, String] the attribute name
      # @param kind [Symbol] +:composite+ or +:single+
      # @param amount_column [Symbol, String] the amount column name
      # @param currency_column [Symbol, String, nil] the currency column name (composite only)
      # @param amount_type [Symbol, nil] +:integer+ or +:decimal+
      # @return [AttributeSpec]
      def register_money_attribute_spec(name, kind:, amount_column:, currency_column: nil, amount_type: nil)
        spec = MoneyAttribute::AttributeSpec.new(
          name: name.to_s,
          kind: kind,
          amount_column: amount_column.to_s,
          currency_column: currency_column&.to_s,
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

      # Returns a frozen Set of registered money attribute names.
      #
      # @return [Set<String>]
      def money_attribute_names_set
        PATTERNS.fetch_or_store(:"#{self}_name_set") { money_attribute_specs.keys.to_set.freeze }
      end

      # Returns a pre-compiled regex matching any registered money attribute name.
      #
      # @return [Regexp]
      def money_attribute_name_pattern
        PATTERNS.fetch_or_store(:"#{self}_name_pattern") do
          names = money_attribute_specs.keys.map { |n| Regexp.escape(n) }
          /\b(#{names.join('|')})\b/i
        end
      end
    end
  end
end
