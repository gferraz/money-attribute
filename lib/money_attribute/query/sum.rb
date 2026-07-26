# frozen_string_literal: true

module MoneyAttribute
  # Sums amount columns and returns `Array<Mint::Money>`.
  #
  # Composite attributes use SQL GROUP BY on the currency column:
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
  # Multiple attributes return a hash of arrays:
  #
  #   Offer.sum_amount(:price, :discount)
  #   # => { price: [Mint::Money(30.0, 'EUR')], discount: [Mint::Money(15.0, 'BRL')] }
  #
  module SumAmount
    def sum_amount(*attrs)
      attrs = attrs.flatten
      raise ArgumentError, 'No attributes specified' if attrs.empty?

      results = attrs.index_with { |attr| resolve_sum(attr) }
      results.size == 1 ? results.values.first : results
    end

    private

    def resolve_sum(attr)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        resolve_composite_sum(reflection)
      elsif money_amount_attribute?(attr)
        resolve_single_sum(attr)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end

    def resolve_composite_sum(reflection)
      amount_col, currency_col = reflection.mapping.keys

      grouped = group(currency_col).sum(amount_col)
      grouped.delete(nil)
      return wrap_empty(amount_col) if grouped.empty?

      grouped.map { |currency, raw| wrap_money(raw, currency, amount_col) }
    end

    def resolve_single_sum(attr)
      raw_sum = sum(attr)
      currency = MoneyAttribute.default_currency.code
      [wrap_money(raw_sum, currency, attr)]
    end

    def wrap_empty(column)
      [wrap_money(nil, nil, column)]
    end

    def wrap_money(raw_sum, currency, column)
      return raw_sum if raw_sum.is_a?(Mint::Money)
      return MoneyAttribute.default_currency.zero if raw_sum.nil? || raw_sum.zero?

      resolved = Money::Currency.resolve(currency)
      if klass.integer_column?(column)
        Mint::Money.from_subunits(raw_sum, resolved)
      else
        Mint::Money.from(raw_sum, resolved)
      end
    end
  end
end
