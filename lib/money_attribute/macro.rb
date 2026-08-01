# frozen_string_literal: true

module MoneyAttribute
  # Declares composite money attributes on Active Record models.
  #
  # Provides the +money_attribute+ class method which wires a two-column
  # (amount + currency) backing store to a +Mint::Money+ value object via
  # +composed_of+.
  #
  # @example
  #   class Product < ApplicationRecord
  #     money_attribute :price
  #   end
  module Macro
    extend ActiveSupport::Concern

    # Class methods backing the +money_attribute+ macro.
    #
    # @api private
    module CompositeClassMethods
      include ColumnTypeValidations

      # Normalizes the requested mapping by applying conventions and overrides.
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @param mapping_override [Hash] the user-supplied +mapping:+ option
      # @return [Hash{Symbol => String}] resolved +:amount+ and +:currency+ column names
      # @raise [ArgumentError] if the resolved columns do not exist on the model
      # @api private
      def resolve_mapping(name, mapping_override)
        override = mapping_override.compact
        override.slice!(:amount, :currency)
        override.transform_values!(&:to_s)

        mapping = default_mapping(name).merge(override)

        assert_columns_exist!(name, mapping)
        mapping
      end

      # Returns the default amount/currency mapping for the attribute name.
      #
      # Resolution order: +name_currency+ + +name+ columns, +amount+ + +currency+
      # for +:amount+, then the +name_amount+ + +name_currency+ convention.
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @return [Hash{Symbol => String}] +:amount+ and +:currency+ column names
      # @api private
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
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @param mapping [Hash{Symbol => String}] +:amount+ and +:currency+ column names
      # @return [AttributeSpec] the registered spec
      # @raise [ArgumentError] if either column has an unsupported type
      # @api private
      def register_composite_spec(name, mapping)
        amount_column = column_for_attribute(mapping[:amount])
        currency_column = column_for_attribute(mapping[:currency])

        assert_valid_amount_column!(name, mapping[:amount], amount_column)
        assert_valid_currency_column!(name, mapping[:currency], currency_column)

        register_money_attribute_spec(
          name,
          kind: :composite,
          amount_column: mapping[:amount],
          currency_column: mapping[:currency],
          amount_type: %i[integer bigint].include?(amount_column.type) ? :integer : :decimal
        )
      end

      # Raises when the resolved columns are not present on the model.
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @param mapping [Hash{Symbol => String}] +:amount+ and +:currency+ column names
      # @return [void]
      # @raise [ArgumentError] listing expected vs found columns
      # @api private
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
      #
      # Stores the attribute across two columns (amount + currency). The amount
      # column type determines the storage unit: integer/bigint stores subunits,
      # decimal stores the unit value. Currency is resolved per row.
      #
      # @param name [Symbol, String] the money attribute accessor name
      # @param mapping [Hash] custom column mapping (+:amount+, +:currency+)
      # @return [void]
      #
      # @example
      #   class Product < ApplicationRecord
      #     money_attribute :price
      #     money_attribute :price, mapping: { amount: :base_price, currency: :base_currency }
      #   end
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
