# frozen_string_literal: true

require "sequel"

require_relative "tobox/version"

module Tobox
  class Error < StandardError; end
end

require_relative "tobox/configuration"
require_relative "tobox/fetcher"