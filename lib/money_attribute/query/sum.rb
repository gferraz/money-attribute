# frozen_string_literal: true

module MoneyAttribute
  # Internal sum resolution for the +sum_amount+ query helper.
  #
  # @api private
  module SumAmount
    # Sums money-aware amounts for a single attribute.
    #
    # @param attr [Symbol] a registered money attribute name
    # @return [Array<Mint::Money>] one Money per currency (or one for single-column attributes)
    # @raise [ArgumentError] if the attribute is not a registered money attribute
    # @api private
    def sum_amount(attr)
      raise ArgumentError, 'No attribute specified' if attr.nil?

      spec = money_attribute_spec!(attr)
      if spec.composite?
        resolve_composite_sum(spec)
      else
        resolve_single_sum(spec)
      end
    end

    private

    # Sums a composite attribute grouped by currency.
    #
    # @param spec [AttributeSpec] the money attribute spec
    # @return [Array<Mint::Money>] one +Mint::Money+ per currency, sorted by
    #   currency code, or a single zero-value Money when no rows match
    # @api private
    def resolve_composite_sum(spec)
      totals = group(spec.currency_column).sum(spec.amount_column)
      return [spec.build_money(0, MoneyAttribute.default_currency)] if totals.empty?

      totals.map { |code, amount| spec.build_money(amount, code) }
            .sort_by(&:currency_code)
    end

    # Sums a fixed-currency single-column attribute.
    #
    # @param spec [AttributeSpec] the money attribute spec
    # @return [Array<Mint::Money>] a single +Mint::Money+ in the default currency
    # @api private
    def resolve_single_sum(spec)
      total = sum(spec.amount_column)

      [spec.build_money(total, MoneyAttribute.default_currency)]
    end
  end
end
