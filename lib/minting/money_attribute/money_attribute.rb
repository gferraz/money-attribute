# frozen_string_literal: true

module Mint
  # MoneyAttribute
  module MoneyAttribute
    extend ActiveSupport::Concern

    class_methods do
      # Money attribute
      def money_attribute(name, currency: Mint.default_currency, mapping: nil)
        currency = Currency.resolve!(currency)
        parser = Parser.new(currency)
        attributes = attribute_names

        if mapping.nil? && attributes.include?(name.to_s)
          if attributes.include?("#{name}_currency")
            mapping = { amount: name, currency: :"#{name}_currency" }
          elsif attributes.include?('currency') && name.to_s == 'amount'
            mapping = { amount: name, currency: :currency }
          end
        end

        if attributes.include?(name.to_s) && mapping.nil?
          col_type = case columns.find { |c| c.name == name.to_s }&.type
                     when :integer, :bigint then ActiveRecord::Type::Integer.new
                     else ActiveRecord::Type::Decimal.new
                     end
          attribute(name, :mint_money, currency:, column_type: col_type)
          normalizes(name, with: parser)
        else
          aggregated = find_money_attributes(name, mapping:)
          amount_col = columns.find { |c| c.name == aggregated[:amount] }
          constructor = if %i[integer bigint].include?(amount_col&.type)
                          lambda { |fractional, currency_code|
                            Money.from_fractional(fractional, Currency.resolve!(currency_code))
                          }
                        else
                          parser
                        end
          options = {
            allow_nil: true, class_name: 'Mint::Money',
            constructor:, converter: parser,
            mapping: {
              aggregated[:amount] => amount_extractor_for(aggregated[:amount]),
              aggregated[:currency] => :currency_code
            }
          }
          composed_of(name, options)
        end
      end

      def amount_extractor_for(column_name)
        col = columns.find { |c| c.name == column_name.to_s }

        case col&.type
        when :bigint, :integer
          :fractional
        else
          :to_d # :decimal, :numeric, unknown
        end
      end

      def find_money_attributes(name, mapping:)
        composite = { amount: "#{name}_amount", currency: "#{name}_currency" }

        if mapping.present?
          composite[:amount] = mapping[:amount].to_s if mapping[:amount]
          composite[:currency] = mapping[:currency].to_s if mapping[:currency]
        end

        missing = composite.values - attribute_names
        if missing.any?
          raise ArgumentError,
                "Could not find columns for :#{name} money attribute. " \
                "Expected: #{composite.values.join(', ')}, " \
                "Found: #{attribute_names.join(', ')}"
        end

        composite
      end
    end
  end
end
