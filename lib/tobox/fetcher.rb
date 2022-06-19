module Tobox
  class Fetcher
    def initialize(configuration)
      @configuration = configuration
      @db = configuration[:database]
      table = configuration[:table]

      @ds = @db[table]

      @pick_next_sql = @ds.select(:id).order(:id).for_update.skip_locked.limit(1)
    end

    def fetch_events
      @db.transaction do
        events = @ds.where(:id => @pick_next_sql).returning.delete

        if block_given?
          events.each do |ev|
            begin
              yield(to_message(ev))
            rescue StandardError => error
              handle_error(ev, error)
            end
          end
          return events.size
        else
          return events.map(&method(:to_message))
        end
      end
    end

    private

    def to_message(event)
      {
        id: event[:id],
        type: event[:type],
        before: (JSON.parse(event[:data_before]) if event[:data_before]),
        after: (JSON.parse(event[:data_after]) if event[:data_after]),
        at: event[:created_at]
      }
    end

    def handle_error(event, error)
      @configuration.lifecycle_events[:error].each do |hd|
        hd.call(event, error)
      end
    end
  end
end