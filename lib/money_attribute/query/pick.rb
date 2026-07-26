# frozen_string_literal: true

module MoneyAttribute
  # Picks a single amount value from a money-aware attribute.
  module PickAmount
    def pick_amount(*attrs)
      raise ArgumentError, 'No attribute specified' if attrs.empty?

      picks = attrs.map { |attr| pick_spec_for(attr) }
      return pick_single(picks.first) if picks.length == 1

      raw = pick(*picks.flat_map(&:columns))
      return raw if raw.nil?

      cursor = 0
      values = picks.map do |spec|
        value, cursor = extract_pick_value(raw, spec, cursor)
        value
      end

      values
    end

    private

    PickSpec = Struct.new(:attr, :columns, :composite, keyword_init: true)

    def pick_spec_for(attr)
      reflection = klass.reflect_on_aggregation(attr)

      if reflection
        amount_col, currency_col = reflection.mapping.keys
        PickSpec.new(attr: attr, columns: [amount_col, currency_col], composite: true)
      elsif money_amount_attribute?(attr)
        PickSpec.new(attr: attr, columns: [attr], composite: false)
      else
        raise ArgumentError, "#{attr} is not a money attribute on #{klass.name}"
      end
    end

    def pick_single(spec)
      raw = pick(*spec.columns)
      return raw if raw.nil?

      spec.composite ? build_money_value(raw[0], raw[1], spec.columns.first) : raw
    end

    def extract_pick_value(raw, spec, cursor)
      return [raw[cursor], cursor + 1] unless spec.composite

      amount = raw[cursor]
      currency = raw[cursor + 1]
      [build_money_value(amount, currency, spec.columns.first), cursor + 2]
    end
  end
end
