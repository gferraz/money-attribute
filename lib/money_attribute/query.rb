# frozen_string_literal: true

module MoneyAttribute
  # Adds `where_money` scope to ActiveRecord models.
  #
  # Supports Range, single Money value, and Array of Money values.
  #
  #   Offer.where_money(price: 10.euros..100.euros)
  #   Offer.where_money(price: 10.euros)
  #   Offer.where_money(price: [10.euros, 20.euros])
  #
  module Query
    extend ActiveSupport::Concern

    class_methods do
      def where_money(conditions)
        scope = all
        conditions.each do |attr, value|
          scope = scope.resolve_money_condition(attr, value)
        end
        scope
      end
    end
  end

  # Internal methods mixed into ActiveRecord::Relation for query building.
  module QueryMethods
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

    def money_amount_attribute?(attr)
      type = klass.type_for_attribute(attr)
      type.respond_to?(:cast_type) && type.cast_type.is_a?(MoneyAttribute::Type)
    end

    def validate_currency_match!(first, second)
      return if first.currency_code == second.currency_code

      raise ArgumentError,
            "Currency mismatch in range: #{first.currency_code} != #{second.currency_code}"
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::Query
  ActiveRecord::Relation.include(MoneyAttribute::QueryMethods)
end
