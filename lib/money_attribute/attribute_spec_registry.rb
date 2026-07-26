# frozen_string_literal: true

module MoneyAttribute
  # Stores money attribute metadata on the model class.
  module AttributeSpecRegistry
    extend ActiveSupport::Concern

    included do
      @money_attribute_specs = {}
      @money_attribute_specs_mutex = Mutex.new

      class << self
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@money_attribute_specs, (@money_attribute_specs || {}).dup)
          subclass.instance_variable_set(:@money_attribute_specs_mutex, Mutex.new)
        end
      end
    end

    class_methods do
      def register_money_attribute_spec(name, kind:, amount_col:, currency_col: nil)
        spec = MoneyAttribute::AttributeSpec.new(
          name: name.to_s,
          kind: kind,
          amount_col: amount_col.to_s,
          currency_col: currency_col&.to_s
        )

        money_attribute_specs_mutex.synchronize do
          @money_attribute_specs = money_attribute_specs.merge(spec.name => spec)
        end
        spec
      end

      def money_attribute_spec(name)
        money_attribute_specs[name.to_s]
      end

      def money_attribute_specs
        @money_attribute_specs ||= {}
      end

      private

      def money_attribute_specs_mutex
        @money_attribute_specs_mutex ||= Mutex.new
      end
    end
  end
end
