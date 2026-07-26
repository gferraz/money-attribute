# frozen_string_literal: true

module MoneyAttribute
  # Resolves `where_money` conditions to backing column queries.
  module MoneyCondition
    def resolve_money_condition(attr, value)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        resolve_composite(reflection, attr, value)
      elsif money_amount_attribute?(attr)
        where(attr => value)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end

    private

    def resolve_composite(reflection, attr, value)
      case value
      when Range then where_composite_range(reflection, value)
      else            where(attr => value)
      end
    end

    def where_composite_range(reflection, range)
      mapping = reflection.mapping
      lower = range.begin
      validate_currency_match!(lower, range.end) if lower.is_a?(Mint::Money)

      where_arel_range(arel_table[mapping.keys.first], mapping.values.first, range)
        .then { |q| composite_currency_filter(q, mapping.keys.last, lower) }
    end

    def composite_currency_filter(scope, currency_col, value)
      value.is_a?(Mint::Money) ? scope.where(currency_col => value.currency_code) : scope
    end

    def where_arel_range(arel_amount, extract, range)
      lower = range.begin
      upper = range.end

      if range.exclude_end?
        where(arel_amount.gteq(lower.public_send(extract)))
          .where(arel_amount.lt(upper.public_send(extract)))
      else
        where(arel_amount.between(lower.public_send(extract)..upper.public_send(extract)))
      end
    end
  end
end
