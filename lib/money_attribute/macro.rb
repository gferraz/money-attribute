# frozen_string_literal: true

module MoneyAttribute
  module Macro
    extend ActiveSupport::Concern

    class_methods do
      def money_attribute(name, currency: MoneyAttribute.default_currency, mapping: nil)
        columns = attribute_names
        currency = ::Mint::Currency.resolve!(currency)
        converter = Converter.new(currency)
        name = name.to_s
        resolved_mapping = mapping || resolve_mapping(name, columns)

        if columns.include?(name) && resolved_mapping.nil?
          define_single_column_money_attribute(name, currency)
        else
          define_composite_money_attribute(name, resolved_mapping, currency)
        end
      end

      private

      # --- Preparation (no side effects) ---

      def resolve_mapping(name, columns)
        return nil unless columns.include?(name)

        if columns.include?("#{name}_currency")
          { amount: name, currency: :"#{name}_currency" }
        elsif columns.include?('currency') && name == 'amount'
          { amount: name, currency: :currency }
        end
      end

      def resolve_composite_for(name, mapping:)
        composite = { amount: "#{name}_amount", currency: "#{name}_currency" }

        composite[:amount]    = mapping[:amount].to_s   if mapping&.key?(:amount)
        composite[:currency]  = mapping[:currency].to_s if mapping&.key?(:currency)

        assert_columns_exist!(name, composite)
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

      def amount_extractor_for(column_name) = integer_column?(column_name) ? :subunits : :to_d

      def money_constructor_for(amount_column)
        default = MoneyAttribute.default_currency
        if integer_column?(amount_column)
          lambda { |amount, currency|
            return nil if amount.nil?

            Mint::Money.from_subunits(amount, currency.presence || default)
          }
        else
          lambda { |amount, currency|
            return nil if amount.nil?

            Mint::Money.from(amount, currency.presence || default)
          }
        end
      end

      def integer_column?(column_name)
        col = columns.find { |c| c.name == column_name }
        %i[integer bigint].include?(col&.type)
      end

      # --- Configuration (registers types, normalizers, composed_of) ---

      def define_single_column_money_attribute(name, currency)
        column_type = integer_column?(name) ? ActiveRecord::Type::Integer.new : ActiveRecord::Type::Decimal.new
        attribute(name.to_sym, :mint_money, currency:, column_type: column_type)
        normalizes(name.to_sym, with: Converter.new(currency))
      end

      def define_composite_money_attribute(name, mapping, currency)
        aggregated = resolve_composite_for(name, mapping:)

        composed_of(name.to_sym, {
                      allow_nil: true,
                      class_name: 'Mint::Money',
                      constructor: money_constructor_for(aggregated[:amount]),
                      converter: Converter.new(currency),
                      mapping: {
                        aggregated[:amount] => amount_extractor_for(aggregated[:amount]),
                        aggregated[:currency] => :currency_code
                      }
                    })
      end
    end
  end
end
