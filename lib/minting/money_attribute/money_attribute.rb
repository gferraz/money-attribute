# frozen_string_literal: true

module Mint
  module MoneyAttribute
    extend ActiveSupport::Concern

    class_methods do
      def money_attribute(name, currency: Mint.default_currency, mapping: nil)
        columns = attribute_names
        currency = Currency.resolve!(currency)
        name = name.to_s
        resolved_mapping = mapping || resolve_mapping(name, columns)

        if columns.include?(name) && resolved_mapping.nil?
          define_single_column_money_attribute(name, currency, Parser.new(currency))
        else
          define_composite_money_attribute(name, resolved_mapping, Parser.new(currency))
        end
      end

      private

      def amount_extractor_for(column_name)
        integer_column?(column_name) ? :fractional : :to_d
      end

      def find_money_attributes(name, mapping:)
        composite = build_composite_mapping(name, mapping)
        assert_columns_exist!(name, composite)
        composite
      end

      # --- Mapping resolution ---

      def resolve_mapping(name, columns)
        return nil unless columns.include?(name)

        if columns.include?("#{name}_currency")
          { amount: name, currency: :"#{name}_currency" }
        elsif columns.include?('currency') && name == 'amount'
          { amount: name, currency: :currency }
        end
      end

      def build_composite_mapping(name, mapping)
        composite = { amount: "#{name}_amount", currency: "#{name}_currency" }
        composite[:amount]    = mapping[:amount].to_s   if mapping&.key?(:amount)
        composite[:currency]  = mapping[:currency].to_s if mapping&.key?(:currency)
        composite
      end

      def assert_columns_exist!(name, composite)
        missing = composite.values - attribute_names
        return if missing.empty?

        raise ArgumentError,
              "Could not find columns for :#{name} money attribute. " \
              "Expected: #{composite.values.join(', ')}, " \
              "Found: #{attribute_names.join(', ')}"
      end

      # --- Attribute definition ---

      def define_single_column_money_attribute(name, currency, parser)
        attribute(name.to_sym, :mint_money, currency:, column_type: column_type_for(name))
        normalizes(name.to_sym, with: parser)
      end

      def define_composite_money_attribute(name, mapping, parser)
        aggregated = find_money_attributes(name, mapping:)

        composed_of(name.to_sym, {
                      allow_nil: true,
                      class_name: 'Mint::Money',
                      constructor: money_constructor_for(aggregated[:amount], parser),
                      converter: parser,
                      mapping: {
                        aggregated[:amount] => amount_extractor_for(aggregated[:amount]),
                        aggregated[:currency] => :currency_code
                      }
                    })
      end

      # --- Column introspection helpers ---

      def find_column(column_name)
        columns.find { |c| c.name == column_name }
      end

      def integer_column?(column_name)
        %i[integer bigint].include?(find_column(column_name)&.type)
      end

      def column_type_for(name)
        integer_column?(name) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
      end

      def money_constructor_for(amount_column, parser)
        if integer_column?(amount_column)
          lambda { |fractional, currency_code|
            Money.from_fractional(fractional, Currency.resolve!(currency_code))
          }
        else
          parser
        end
      end
    end
  end
end
