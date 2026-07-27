# frozen_string_literal: true

module MoneyAttribute
  # Sums amount columns and returns `Array<Mint::Money>`.
  #
  # Composite attributes use SQL GROUP BY on the currency column and sort by
  # currency code for deterministic results:
  #
  #   Offer.sum_amount(:price)
  #   # => [Mint::Money(30.0, 'EUR'), Mint::Money(50.0, 'USD')]
  #
  #   Offer.where_currency(price: 'EUR').sum_amount(:price)
  #   # => [Mint::Money(30.0, 'EUR')]
  #
  # Single-column attributes wrap with default currency:
  #
  #   SimpleOffer.sum_amount(:price)
  #   # => [Mint::Money(60.0, 'BRL')]
  #
  module SumAmount
    # Sums money-aware amounts for a single attribute.
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
