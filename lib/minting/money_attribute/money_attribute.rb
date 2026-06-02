# frozen_string_literal: true

module Mint
  # MoneyAttribute
  module MoneyAttribute
    extend ActiveSupport::Concern

    class_methods do
      # Money attribute
      def money_attribute(name, currency: Mint.default_currency, mapping: nil)
        currency = Mint.assert_valid_currency!(currency)
        parser = Parser.new(currency)
        if attribute_names.include? name.to_s
          attribute(name, :mint_money, currency:)
          normalizes(name, with: parser)
        else
          aggregated = find_money_attributes(name, mapping:)
          options = {
            allow_nil: true, class_name: 'Mint::Money',
            constructor: parser, converter: parser,
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
        return :to_d unless col # safe default

        case col.type # :integer, :decimal, :float — already adapter-normalized
        when :integer then :fractional
        else :to_d # :decimal, :numeric, unknown
        end
      end

      def find_money_attributes(name, mapping:)
        composite = if mapping.present?
                      { amount: mapping.key(:amount).to_s, currency: mapping.key(:currency).to_s }
                    else
                      { amount: "#{name}_amount", currency: "#{name}_currency" }
                    end
        if (composite.values & attribute_names).size != 2
          raise ArgumentError, "Could not find attributes to map to #{name} money attribute"
        end

        composite
      end
    end
  end
end
