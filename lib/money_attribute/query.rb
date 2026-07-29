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
      #
      # @param conditions [Hash{Symbol => String}] attribute name to currency code
      # @return [ActiveRecord::Relation]
      # @raise [ArgumentError] if the attribute is not a composite money attribute
      def where_currency(conditions)
        scope = all
        conditions.each { |attr, value| scope = scope.resolve_currency_condition(attr, value) }
        scope
      end

      # Filters by amount for one or more money attributes.
      #
      # Accepts a hash of conditions or a SQL string with +?+ placeholders.
      # Hash: +{ attr: value }+, supports +Mint::Money+, +Range+, +Array+.
      # SQL: only money attribute names, +and+, +or+, +not+, +is+, +null+.
      #
      # @param args [Array] a condition hash, or a SQL string with bind values
      # @return [ActiveRecord::Relation]
      # @raise [ArgumentError] if an identifier is not a registered money attribute
      def where_amount(*args)
        if args.first.is_a?(Hash)
          scope = all
          args.first.each { |attr, value| scope = scope.resolve_amount_condition(attr, value) }
          scope
        else
          all.resolve_amount_condition_from_sql(*args)
        end
      end

      # Orders by amount for one or more money attributes.
      #
      # Composite attributes sort by currency ASC first, then amount.
      #
      # @param conditions [Hash{Symbol => Symbol}] attribute name to +:asc+ or +:desc+
      # @return [ActiveRecord::Relation]
      # @raise [ArgumentError] if the attribute is not a registered money attribute
      def order_by_amount(conditions)
        scope = all
        conditions.each { |attr, dir| scope = scope.resolve_amount_order(attr, dir || :asc) }
        scope
      end

      # Plucks money-aware amounts from the current relation.
      #
      #   Offer.pluck_amount(:price)
      #   # => [Mint::Money(10.0, 'EUR'), Mint::Money(20.0, 'USD')]
      #
      # @param attrs [Array<Symbol>] one or more registered money attribute names
      # @return [Array<Mint::Money>] for a single attribute
      # @return [Array<Array>] for multiple attributes, one row array per attribute
      # @raise [ArgumentError] if any attribute is not a registered money attribute
      def pluck_amount(*attrs)
        all.pluck_amount(*attrs)
      end

      # Picks a single money-aware value from the current relation.
      #
      #   Offer.pick_amount(:price)
      #   # => Mint::Money(10.0, 'EUR')
      #
      # @param attrs [Array<Symbol>] one or more registered money attribute names
      # @return [Mint::Money, Array, nil] Money for a single attribute, row array for multiple, nil if empty
      # @raise [ArgumentError] if any attribute is not a registered money attribute
      def pick_amount(*attrs)
        all.pick_amount(*attrs)
      end

      # Sums money-aware amounts, grouping by currency for composite attributes.
      #
      #   Offer.sum_amount(:price)
      #   # => [Mint::Money(30.0, 'EUR'), Mint::Money(50.0, 'USD')]
      #
      # @param attr [Symbol] a registered money attribute name
      # @return [Array<Mint::Money>] one Money per currency (or one for single-column attributes)
      # @raise [ArgumentError] if the attribute is not a registered money attribute
      def sum_amount(attr)
        all.sum_amount(attr)
      end
    end
  end

  # :nodoc:
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
