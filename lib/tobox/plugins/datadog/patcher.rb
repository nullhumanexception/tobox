# frozen_string_literal: true

require "datadog/tracing/contrib/patcher"

module Datadog
  module Tracing
    module Contrib
      module Tobox
        module Patcher
          include Contrib::Patcher

          module_function

          def target_version
            Integration.version
          end

          def patch
            # server-patches provided by plugin(:sidekiq)
            # TODO: use this once we have a producer side
          end
        end
      end
    end
  end
end
