# frozen_string_literal: true

module MoneyAttribute
  INTEGER_CONSTRUCTOR = lambda do |amount, currency|
    next nil if amount.nil?

    resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
    Mint::Money.from_subunits(amount, resolved)
  end.freeze

  DECIMAL_CONSTRUCTOR = lambda do |amount, currency|
    next nil if amount.nil?

    resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
    Mint::Money.from(amount, resolved)
  end.freeze

  AttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, :amount_type, keyword_init: true) do
    # Returns true when the spec describes a two-column money attribute.
    def composite? = kind == :composite

    # Returns true when the spec describes a single-column money attribute.
    def single? = kind == :single

    # Returns the backing database columns for the attribute.
    def columns
      @columns ||= (composite? ? [amount_col, currency_col] : [amount_col]).freeze
    end

    # Returns true when the amount column stores subunits.
    def integer_amount? = amount_type == :integer

    # Returns the extractor used by `composed_of` for the amount column.
    def amount_extractor = integer_amount? ? :subunits : :to_d

    # Returns the `composed_of` mapping for amount and currency columns.
    def composed_of_mapping = { amount_col => amount_extractor, currency_col => :currency_code }

    # Builds the constructor used by `composed_of` to instantiate money values.
    def constructor
      integer_amount? ? INTEGER_CONSTRUCTOR : DECIMAL_CONSTRUCTOR
    end

    # Converts a raw amount and currency into a `Mint::Money` value.
    def build_money(amount, currency)
      return unless amount
      return amount if amount.is_a?(Mint::Money)

      constructor.call(amount, currency)
    end

    # Normalizes a query value to the column's storage format.
    def normalize_query_value(value)
      return value unless integer_amount?
      return value.subunits if value.is_a?(Mint::Money)

      value
    end
  end
end
