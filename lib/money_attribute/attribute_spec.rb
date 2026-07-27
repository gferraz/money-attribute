# frozen_string_literal: true

module MoneyAttribute
  AttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, :amount_type, keyword_init: true) do
    # Returns true when the spec describes a two-column money attribute.
    def composite? = kind == :composite

    # Returns true when the spec describes a single-column money attribute.
    def single? = kind == :single

    # Returns the backing database columns for the attribute.
    def columns = composite? ? [amount_col, currency_col] : [amount_col]

    # Returns true when the amount column stores subunits.
    def integer_amount? = amount_type == :integer

    # Returns the extractor used by `composed_of` for the amount column.
    def amount_extractor = integer_amount? ? :subunits : :to_d

    # Returns the `composed_of` mapping for amount and currency columns.
    def composed_of_mapping = { amount_col => amount_extractor, currency_col => :currency_code }

    # Builds the constructor used by `composed_of` to instantiate money values.
    def constructor
      method = integer_amount? ? :from_subunits : :from

      lambda do |amount, currency|
        next nil if amount.nil?

        resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
        Mint::Money.public_send(method, amount, resolved)
      end
    end

    # Converts a raw amount and currency into a `Mint::Money` value.
    def build_money(amount, currency)
      return unless amount
      return amount if amount.is_a?(Mint::Money)

      resolved = Money::Currency.resolve(currency)

      if integer_amount?
        Mint::Money.from_subunits(amount, resolved)
      else
        Mint::Money.from(amount, resolved)
      end
    end

    # Returns the zero money value for the application default currency.
    def zero_money
      MoneyAttribute.default_currency.zero
    end

    # Returns the wrapped money value, or zero money when the amount is blank.
    def money_or_zero(amount, currency)
      return zero_money if amount.nil? || amount.zero?

      build_money(amount, currency)
    end
  end
end
