# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module Macro
    extend ActiveSupport::Concern

    # :nodoc:
    module CompositeClassMethods
      def resolve_mapping(name, mapping_override)
        override = mapping_override.compact
        override.slice!(:amount, :currency)
        override.transform_values!(&:to_s)

        mapping = default_mapping(name).merge(override)

        assert_columns_exist!(name, mapping)
        mapping
      end

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

      def register_composite_spec(name, mapping)
        register_money_attribute_spec(
          name,
          kind: :composite,
          amount_col: mapping[:amount],
          currency_col: mapping[:currency]
        )
      end

      def assert_columns_exist!(name, mapping)
        missing = mapping.values - attribute_names
        return if missing.empty?

        raise ArgumentError,
              "Could not find columns for :#{name} money attribute. " \
              "Expected: #{mapping.values.join(', ')}, " \
              "Found: #{attribute_names.join(', ')}"
      end

      def amount_extractor_for(column_name) = integer_column?(column_name) ? :subunits : :to_d

      def money_constructor_for(amount_column)
        if integer_column?(amount_column)
          build_money_constructor(:from_subunits)
        else
          build_money_constructor(:from)
        end
      end

      def build_money_constructor(method)
        lambda do |amount, currency|
          next nil if amount.nil?

          resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
          Mint::Money.public_send(method, amount, resolved)
        end
      end

      def integer_column?(column_name)
        col = columns.find { |c| c.name == column_name }
        %i[integer bigint].include?(col&.type)
      end
    end

    class_methods do
      def money_attribute(name, mapping: {})
        name = name.to_s
        mapping = resolve_mapping(name, mapping)
        spec = register_composite_spec(name, mapping)

        composed_of(name.to_sym, {
                      allow_nil: true,
                      class_name: 'Mint::Money',
                      constructor: money_constructor_for(spec.amount_col),
                      converter: Converter.new,
                      mapping: {
                        spec.amount_col => amount_extractor_for(spec.amount_col),
                        spec.currency_col => :currency_code
                      }
                    })
      end
    end

    included do
      extend CompositeClassMethods
    end
  end
end
