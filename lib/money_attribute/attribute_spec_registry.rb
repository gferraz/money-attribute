# frozen_string_literal: true

require 'concurrent/map'

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  #
  # Holds a per-model registry of {AttributeSpec} objects plus derived caches
  # (name set, regex patterns) populated lazily on first access.
  #
  # @api private
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    REGISTRY = Concurrent::Map.new
    PATTERNS = Concurrent::Map.new
    QUERY_PLANS = Concurrent::Map.new

    class_methods do
      # Registers a money attribute spec for the current model class.
      #
      # @param name [Symbol, String] the attribute name
      # @param kind [Symbol] +:composite+ or +:single+
      # @param amount_column [Symbol, String] the amount column name
      # @param currency_column [Symbol, String, nil] the currency column name (composite only)
      # @param amount_type [Symbol, nil] +:integer+ or +:decimal+
      # @return [AttributeSpec]
      # @api private
      def register_money_attribute_spec(name, kind:, amount_column:, currency_column: nil, amount_type: nil)
        spec = MoneyAttribute::AttributeSpec.new(
          name: name.to_s,
          kind: kind,
          amount_column: amount_column.to_s,
          currency_column: currency_column&.to_s,
          amount_type: amount_type
        )

        money_attribute_specs[spec.name] = spec
        PATTERNS.delete(:"#{self}_name_set")
        PATTERNS.delete(:"#{self}_name_pattern")
        QUERY_PLANS.delete(self)
        spec
      end

      # Returns the registered money attribute spec for the given name.
      #
      # @param name [Symbol, String] the attribute name
      # @return [AttributeSpec, nil]
      # @api private
      def money_attribute_spec(name)
        REGISTRY[self]&.fetch(name.to_s, nil)
      end

      # Returns the registry hash for the current model class.
      #
      # @return [Hash{String => AttributeSpec}]
      # @api private
      def money_attribute_specs
        REGISTRY.fetch_or_store(self) { {} }
      end

      # Returns a frozen Set of registered money attribute names.
      #
      # @return [Set<String>]
      # @api private
      def money_attribute_names_set
        PATTERNS.fetch_or_store(:"#{self}_name_set") { money_attribute_specs.keys.to_set.freeze }
      end

      # Returns a pre-compiled regex matching any registered money attribute name.
      #
      # @return [Regexp]
      # @api private
      def money_attribute_name_pattern
        PATTERNS.fetch_or_store(:"#{self}_name_pattern") do
          names = money_attribute_specs.keys.map { |n| Regexp.escape(n) }
          /\b(#{names.join('|')})\b/i
        end
      end
    end

    class_methods do
      # Returns whether the model has a registered money attribute.
      #
      # @param name [Symbol, String] the attribute name
      # @return [Boolean]
      def money_attribute?(name)
        !money_attribute_spec(name).nil?
      end

      # Returns the storage mode for a registered money attribute.
      #
      # @param name [Symbol, String] the attribute name
      # @return [Symbol, nil] +:composite+, +:single+, or +nil+
      def money_attribute_kind(name)
        money_attribute_spec(name)&.kind
      end

      # Returns the compiled string-query cache for the current model class.
      #
      # @return [Concurrent::Map]
      # @api private
      def money_attribute_query_plan_cache
        QUERY_PLANS.fetch_or_store(self) { Concurrent::Map.new }
      end
    end
  end
end
