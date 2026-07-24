# frozen_string_literal: true

require 'active_support/current_attributes'

module MoneyAttribute
  # Per-request currency container. Set MoneyAttribute::Current.currency in your
  # controller (or a before_action) to override the configured default for that request.
  # Automatically reset after each request by MoneyAttribute::Middleware.
  class Current < ::ActiveSupport::CurrentAttributes
    attribute :currency
  end
end
