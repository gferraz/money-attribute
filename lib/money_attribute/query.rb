# frozen_string_literal: true

require_relative 'query/helpers'
require_relative 'query/currency_condition'
require_relative 'query/amount_condition'
require_relative 'query/amount_order'
require_relative 'query/pluck'
require_relative 'query/pick'
require_relative 'query/sum'

module MoneyAttribute
  # Money-aware query helpers for ActiveRecord.
  #
  #   Offer.where_currency(price: 'EUR')
  #   Offer.where_amount(price: 10..100)
  #   Offer.order_by_amount(price: :desc)
  #   Offer.pluck_amount(:price)
  #   Offer.pick_amount(:price)
  #   Offer.sum_amount(:price)
  #
  module Query
    extend ActiveSupport::Concern

    class_methods do
      # Filters by currency for one or more money attributes.
      def where_currency(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_currency_condition(attr, value) }
        scope
      end

      # Filters by amount for one or more money attributes.
      def where_amount(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_amount_condition(attr, value) }
        scope
      end

      # Orders by amount for one or more money attributes.
      def order_by_amount(conditions)
        scope = all
        conditions.each { |attr, dir| scope = scope.resolve_amount_order(attr, dir || :asc) }
        scope
      end

      # Plucks money-aware amounts from the current relation.
      def pluck_amount(*attrs)
        all.pluck_amount(*attrs)
      end

      # Picks money-aware amounts from the current relation.
      def pick_amount(*attrs)
        all.pick_amount(*attrs)
      end

      # Sums money-aware amounts from the current relation.
      def sum_amount(attr)
        all.sum_amount(attr)
      end
    end
  end

  # Internal methods mixed into ActiveRecord::Relation for query building.
  module QueryMethods
    include QueryHelpers
    include CurrencyCondition
    include AmountCondition
    include AmountOrder
    include PluckAmount
    include PickAmount
    include SumAmount
  end
end

ActiveSupport.on_load(:active_record) do
  include MoneyAttribute::AttributeSpecRegistry
  include MoneyAttribute::Query
  ActiveRecord::Relation.include(MoneyAttribute::QueryMethods)
end
