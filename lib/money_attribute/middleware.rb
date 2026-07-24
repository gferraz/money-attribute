# frozen_string_literal: true

module MoneyAttribute
  # Rack middleware that resets MoneyAttribute::Current after each request.
  # This ensures per-request currency values don't leak between requests.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      MoneyAttribute::Current.reset
    end
  end
end
