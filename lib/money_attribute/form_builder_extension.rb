# frozen_string_literal: true

module MoneyAttribute
  module FormBuilderExtension
    def money_field(method, options = {})
      money = object.public_send(method)
      value = money ? money.to_s : nil

      @template.text_field_tag(field_name(method), value,
                               { id: field_id(method) }.merge(options))
    end

    def money_amount(method, options = {})
      money_from_column = object.public_send(method)
      value = money_from_column ? money_from_column.to_s : nil

      @template.text_field_tag(field_name(method), value,
                               { id: field_id(method) }.merge(options))
    end
  end
end
