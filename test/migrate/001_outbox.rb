# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:outbox) do
      primary_key :id
      column :type, :varchar, null: false
      column :data_before, :json, null: true
      column :data_after, :json, null: true
      column :created_at, "timestamp without time zone", null: false, default: Sequel::CURRENT_TIMESTAMP
      column :attempts, :integer, null: false, default: 0
      column :run_at, "timestamp without time zone", null: true
      column :last_error, :text, null: true

      index Sequel.desc(:run_at) # , where: { : :ascequel[:attempts] < max_attempts }
    end
  end

  down do
    drop_table(:outbox)
  end
end
