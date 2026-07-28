# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module SumAmount
    # Sums money-aware amounts for a single attribute.
    #
    # @param attr [Symbol] a registered money attribute name
    # @return [Array<Mint::Money>] one Money per currency (or one for single-column attributes)
    # @raise [ArgumentError] if the attribute is not a registered money attribute
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
    def resolve_composite_sum(spec)
      totals = group(spec.currency_col).sum(spec.amount_col)
      return [spec.build_money(0, MoneyAttribute.default_currency)] if totals.empty?

      totals.map { |code, amount| spec.build_money(amount, code) }
            .sort_by(&:currency_code)
    end

    # Sums a fixed-currency single-column attribute.
    def resolve_single_sum(spec)
      total = sum(spec.amount_col)

      [spec.build_money(total, MoneyAttribute.default_currency)]
    end
  end
end
