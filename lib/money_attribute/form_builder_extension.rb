# frozen_string_literal: true

module MoneyAttribute
  # :nodoc:
  module FormBuilderExtension
    def money_field(method, options = {})
      money = object.public_send(method)
      value = money&.to_fs

      @template.text_field_tag(field_name(method), value,
                               { id: field_id(method) }.merge(options))
    end

    def money_amount_field(method, options = {})
      money_from_column = object.public_send(method)
      value = money_from_column&.to_d

      @template.number_field_tag(field_name(method), value,
                                 { id: field_id(method) }.merge(options))
    end
  end
end
