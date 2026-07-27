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
        columns = attribute_names

        if columns.include?("#{name}_currency") && columns.include?(name)
          { amount: name, currency: "#{name}_currency" }
        elsif name == 'amount' && columns.include?('currency')
          { amount: name, currency: 'currency' }
        else
          { amount: "#{name}_amount", currency: "#{name}_currency" }
        end
      end

      # Registers the composite money attribute spec for the model.
      def register_composite_spec(name, mapping)
        register_money_attribute_spec(
          name,
          kind: :composite,
          amount_col: mapping[:amount],
          currency_col: mapping[:currency],
          amount_type: amount_column_type(mapping[:amount])
        )
      end

      # Raises when the resolved columns are not present on the model.
      def assert_columns_exist!(name, mapping)
        missing = mapping.values - attribute_names
        return if missing.empty?

        raise ArgumentError,
              "Could not find columns for :#{name} money attribute. " \
              "Expected: #{mapping.values.join(', ')}, " \
              "Found: #{attribute_names.join(', ')}"
      end

      # Returns the storage type for the amount column.
      def amount_column_type(column_name)
        column = columns.find { |c| c.name == column_name }
        %i[integer bigint].include?(column&.type) ? :integer : :decimal
      end
    end

    class_methods do
      # Declares a composite money attribute on the model.
      def money_attribute(name, mapping: {})
        name = name.to_s
        mapping = resolve_mapping(name, mapping)
        spec = register_composite_spec(name, mapping)

        composed_of(name.to_sym, {
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
