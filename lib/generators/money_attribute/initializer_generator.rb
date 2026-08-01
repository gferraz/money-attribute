# frozen_string_literal: true

module MoneyAttribute
  # Generator namespace for money_attribute.
  module Generators
    # Rails generator that installs the money_attribute initializer.
    #
    # @example
    #   rails generate money_attribute:initializer
    #
    # @api private
    class InitializerGenerator < ::Rails::Generators::Base
      source_root File.expand_path('../templates', __dir__)

      desc 'Creates MoneyAttribute initializer.'

      # Copies the initializer template into the application.
      #
      # @return [void]
      def copy_initializer
        copy_file 'money_attribute.rb', 'config/initializers/money_attribute.rb'
      end
    end
  end
end
