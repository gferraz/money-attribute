# frozen_string_literal: true

module MoneyAttribute
  # Plucks amount values from money-aware attributes.
  module PluckAmount
    def pluck_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      specs = attrs.map { |attr| money_attribute_spec!(attr) }
      return pluck_single_amount(specs.first) if specs.length == 1

      pluck(*specs.flat_map(&:columns)).map do |row|
        extract_money_row(row, specs)
      end
    end

    private

    def pluck_single_amount(spec)
      return pluck(spec.amount_col) if spec.single?

      pluck(spec.amount_col, spec.currency_col).map do |amount, currency|
        spec.build_money(amount, currency)
      end
    end

    def extract_money_row(row, specs)
      values = []
      cursor = 0

      specs.each do |spec|
        if spec.single?
          values << row[cursor]
          cursor += 1
        else
          values << spec.build_money(row[cursor], row[cursor + 1])
          cursor += 2
        end
      end

      values
    end
  end
end
