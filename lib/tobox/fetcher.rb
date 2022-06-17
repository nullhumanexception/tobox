module Tobox
  class Fetcher
    def initialize(configuration)
      @db = configuration[:database]
      table = configuration[:table]

      @ds = @db[table]

      @pick_next_sql = @ds.select(:id).order(:id).for_update.skip_locked.limit(1)
    end

    def fetch_event
      @db.transaction do
        event = @ds.where(:id => @pick_next_sql).returning.delete.first

        if block_given?
          yield event if event
        else
          return event
        end

      end
    end
  end
end