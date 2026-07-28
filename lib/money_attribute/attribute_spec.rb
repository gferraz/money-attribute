# frozen_string_literal: true

module MoneyAttribute
  # @private Constructor for integer (subunit) columns used by +composed_of+.
  INTEGER_CONSTRUCTOR = lambda do |amount, currency|
    next nil if amount.nil?

    resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
    Mint::Money.from_subunits(amount, resolved)
  end.freeze

  # @private Constructor for decimal (unit value) columns used by +composed_of+.
  DECIMAL_CONSTRUCTOR = lambda do |amount, currency|
    next nil if amount.nil?

    resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
    Mint::Money.from(amount, resolved)
  end.freeze

  # Value object holding metadata for a registered money attribute.
  #
  # Created by +money_attribute+ or +money_amount+ and stored in the class-level registry.
  # Used by query helpers to resolve column names, build Money values, and generate SQL.
  AttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, :amount_type, keyword_init: true) do
    # @return [Boolean] +true+ when the spec describes a two-column (amount + currency) attribute.
    def composite? = kind == :composite

    # @return [Boolean] +true+ when the spec describes a single-column (fixed currency) attribute.
    def single? = kind == :single

    # Returns the backing database columns for the attribute.
    #
    # @return [Array<String>] two-element array for composite, one-element for single.
    def columns
      @columns ||= (composite? ? [amount_col, currency_col] : [amount_col]).freeze
    end

    # @return [Boolean] +true+ when the amount column stores subunits (bigint).
    def integer_amount? = amount_type == :integer

    # @return [Symbol] +:subunits+ for integer columns, +:to_d+ for decimal columns.
    def amount_extractor = integer_amount? ? :subunits : :to_d

    # @return [Hash{String => Symbol}] mapping suitable for +composed_of+.
    def composed_of_mapping = { amount_col => amount_extractor, currency_col => :currency_code }

    # @return [Proc] the constructor lambda used by +composed_of+ to instantiate Money values.
    def constructor
      integer_amount? ? INTEGER_CONSTRUCTOR : DECIMAL_CONSTRUCTOR
    end

    # Converts a raw amount and currency into a +Mint::Money+ value.
    #
    # @param amount [Integer, BigDecimal, nil] the raw column value
    # @param currency [String, Mint::Currency, nil] the currency code or object
    # @return [Mint::Money, nil] the resolved money value, or nil when amount is nil
    def build_money(amount, currency)
      return unless amount
      return amount if amount.is_a?(Mint::Money)

      constructor.call(amount, currency)
    end

    # Normalizes a query value to the column's storage format.
    #
    # Composite attributes: decomposes +Mint::Money+ to subunits via +.subunits+.
    # Single-column attributes: passes through (the registered Type handles serialization).
    #
    # @param value [Mint::Money, Numeric] the query value
    # @return [Integer, BigDecimal, Mint::Money] the normalized value
    def normalize_query_value(value)
      return value unless integer_amount?
      return value.subunits if value.is_a?(Mint::Money)

      value
    end
  end
end
