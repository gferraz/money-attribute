# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_amount` conditions to amount column queries.
  module AmountCondition
    # Builds an amount filter for the registered money attribute.
    def resolve_amount_condition(attr, value)
      spec = money_attribute_spec!(attr)
      col = arel_table[spec.amount_col]

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

    # Normalizes a scalar value to the column's storage format.
    def normalize_amount_value(spec, value)
      spec.normalize_query_value(value)
    end
  end
end
