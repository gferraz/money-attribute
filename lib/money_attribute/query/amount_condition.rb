# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module AmountCondition
    # Builds an amount filter for the registered money attribute.
    #
    # @param attr [Symbol] the money attribute name
    # @param value [Mint::Money, Numeric, Range, Array] the filter value
    # @return [ActiveRecord::Relation]
    # @raise [ArgumentError] if the attribute is not a registered money attribute
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)
      col = arel_table[spec.amount_column]

      where(build_amount_predicate(col, spec, value))
    end

    private

    # Builds an Arel predicate for the given amount value.
    def build_amount_predicate(col, spec, value)
      case value
      when Range
        low = normalize_amount_value(spec, value.begin)
        high = normalize_amount_value(spec, value.end)
        pred = col.gteq(low)
        value.exclude_end? ? pred.and(col.lt(high)) : pred.and(col.lteq(high))
      when Array
        col.in(value.map { |v| normalize_amount_value(spec, v) })
      else
        col.eq(normalize_amount_value(spec, value))
      end
    end

    # Normalizes a scalar value for Arel comparison.
    #
    # Composite attributes: the amount column is a plain column with no custom Type,
    # so we must pre-normalize Money to the raw storage value (subunits or decimal).
    # Single-column attributes: the column has a registered Type that handles
    # serialization, so we pass Money objects through directly to avoid double conversion.
    def normalize_amount_value(spec, value)
      return value unless spec.composite?

      spec.normalize_query_value(value)
    end
  end
end
