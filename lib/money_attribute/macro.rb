# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module Macro
    extend ActiveSupport::Concern

    # :nodoc:
    module CompositeClassMethods
      # Normalizes the requested mapping by applying conventions and overrides.
      def resolve_mapping(name, mapping_override)
        override = mapping_override.compact
        override.slice!(:amount, :currency)
        override.transform_values!(&:to_s)

        mapping = default_mapping(name).merge(override)

        assert_columns_exist!(name, mapping)
        mapping
      end

      # Returns the default amount/currency mapping for the attribute name.
      def default_mapping(name)
        name = name.to_s
        names = column_names

        if names.include?("#{name}_currency") && names.include?(name)
          { amount: name, currency: "#{name}_currency" }
        elsif name == 'amount' && names.include?('currency')
          { amount: name, currency: 'currency' }
        else
          { amount: "#{name}_amount", currency: "#{name}_currency" }
        end
      end

      # Registers the composite money attribute spec for the model.
      def register_composite_spec(name, mapping)
        column = column_for_attribute(mapping[:amount])
        register_money_attribute_spec(
          name,
          kind: :composite,
          amount_col: mapping[:amount],
          currency_col: mapping[:currency],
          amount_type: %i[integer bigint].include?(column.type) ? :integer : :decimal
        )
      end

      # Raises when the resolved columns are not present on the model.
      def assert_columns_exist!(name, mapping)
        missing = mapping.values - column_names
        return if missing.empty?

        raise ArgumentError,
              "Could not find columns for :#{name} money attribute. " \
              "Expected: #{mapping.values.join(', ')}, " \
              "Found: #{attribute_names.join(', ')}"
      end
    end

    class_methods do
      # Declares a composite money attribute on the model.
      def money_attribute(name, mapping: {})
        mapping = resolve_mapping(name, mapping)
        spec = register_composite_spec(name, mapping)

        composed_of(name, {
                      allow_nil: true,
                      class_name: 'Mint::Money',
                      constructor: spec.constructor,
                      converter: Converter.default,
                      mapping: spec.composed_of_mapping
                    })
      end
    end

    included do
      extend CompositeClassMethods
    end
  end
end
