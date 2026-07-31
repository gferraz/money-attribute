# frozen_string_literal: true

module MoneyAttribute
  # Form builder methods for money attributes.
  #
  # Included into +ActionView::Helpers::FormBuilder+ by the railtie,
  # providing two helper methods that mirror Rails' +text_field+ and
  # +number_field+ but work with +Mint::Money+ attribute values.
  #
  # Both helpers render unbound <tt>&lt;input&gt;</tt> tags (not scoped to
  # the form builder's object name), so the submitted value is accessible
  # via +params+ directly rather than through +params[object_name]+.
  #
  # @example In a view
  #   <%= form_with model: @product do |f| %>
  #     <%= f.money_field :price %>
  #     <%= f.money_amount_field :discount %>
  #   <% end %>
  module FormBuilderExtension
    # Renders a text input for a composed (amount + currency) money attribute.
    #
    # Displays the formatted money string (e.g. +"R$ 1.234,56"+) via
    # {Mint::Money#to_fs}. The raw value is submitted as a string; the
    # application should parse it on the receiving end, typically using
    # {MoneyAttribute::Converter#parse}.
    #
    # @param method [Symbol] the money attribute accessor name
    # @param options [Hash] HTML attributes passed through to the input tag
    # @return [String] an HTML <tt>&lt;input type="text"&gt;</tt> tag
    #
    # @example
    #   f.money_field :price
    #   # => <input type="text" id="product_price" name="product_price" value="R$ 1.234,56">
    #
    # @example With CSS class
    #   f.money_field :price, class: "form-control"
    def money_field(method, options = {})
      money = object.public_send(method)
      value = money&.to_fs

      @template.text_field_tag(field_name(method), value,
                               { id: field_id(method) }.merge(options))
    end

    # Renders a number input for a single-column (fixed-currency) money attribute.
    #
    # Displays the raw decimal value (e.g. +"1234.56"+) via
    # {Mint::Money#to_d}. This is suitable for attributes backed by a single
    # column where the currency is fixed per application config.
    #
    # @param method [Symbol] the money attribute accessor name
    # @param options [Hash] HTML attributes passed through to the input tag
    # @return [String] an HTML <tt>&lt;input type="number"&gt;</tt> tag
    #
    # @example
    #   f.money_amount_field :discount
    #   # => <input type="number" id="product_discount" name="product_discount" value="1234.56">
    #
    # @example With step and min
    #   f.money_amount_field :discount, step: 0.01, min: 0
    def money_amount_field(method, options = {})
      money_from_column = object.public_send(method)
      value = money_from_column&.to_d

      @template.number_field_tag(field_name(method), value,
                                 { id: field_id(method) }.merge(options))
    end
  end
end
