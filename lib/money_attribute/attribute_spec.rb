# frozen_string_literal: true

module MoneyAttribute
  AttributeSpec = Struct.new(:name, :kind, :amount_col, :currency_col, keyword_init: true) do
    def composite?
      kind == :composite
    end

    def single?
      kind == :single
    end

    def columns
      composite? ? [amount_col, currency_col] : [amount_col]
    end
  end
end
