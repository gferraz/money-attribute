# frozen_string_literal: true

module MoneyAttribute
  AttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, :amount_type, keyword_init: true) do
    def composite?
      kind == :composite
    end

    def single?
      kind == :single
    end

    def columns
      composite? ? [amount_col, currency_col] : [amount_col]
    end

    def integer_amount?
      amount_type == :integer
    end

    def amount_extractor
      integer_amount? ? :subunits : :to_d
    end

    def composed_of_mapping
      { amount_col => amount_extractor, currency_col => :currency_code }
    end

    def constructor
      method = integer_amount? ? :from_subunits : :from

      lambda do |amount, currency|
        next nil if amount.nil?

        resolved = Money::Currency.resolve(currency.presence || MoneyAttribute.default_currency) || 'XXX'
        Mint::Money.public_send(method, amount, resolved)
      end
    end

    def build_money(raw_amount, currency)
      return raw_amount if raw_amount.is_a?(Mint::Money)
      return nil if raw_amount.nil?

      resolved = Money::Currency.resolve(currency)

      if integer_amount?
        Mint::Money.from_subunits(raw_amount, resolved)
      else
        Mint::Money.from(raw_amount, resolved)
      end
    end

    def money_or_zero(raw_amount, currency)
      return zero_money if raw_amount.nil? || raw_amount.zero?

      build_money(raw_amount, currency)
    end

    def zero_money
      MoneyAttribute.default_currency.zero
    end
  end
end
