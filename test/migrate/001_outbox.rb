# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:outbox) do
      primary_key :id
      column :type, :varchar, null: false
      column :unique_id, :varchar, null: true
      column :data_before, :json, null: true
      column :data_after, :json, null: true
      column :created_at, "timestamp without time zone", null: false, default: Sequel::CURRENT_TIMESTAMP
      column :attempts, :integer, null: false, default: 0
      column :run_at, "timestamp without time zone", null: true
      column :last_error, :text, null: true
      column :metadata, :json, null: true

      index Sequel.desc(:run_at) # , where: { : :ascequel[:attempts] < max_attempts }
    end

    create_table(:outbox_with_group) do
      primary_key :id
      column :group_id, :integer, null: true
      column :type, :varchar, null: false
      column :data_before, :json, null: true
      column :data_after, :json, null: true
      column :created_at, "timestamp without time zone", null: false, default: Sequel::CURRENT_TIMESTAMP
      column :attempts, :integer, null: false, default: 0
      column :run_at, "timestamp without time zone", null: true
      column :last_error, :text, null: true
      column :metadata, :json, null: true

      index :group_id
      index Sequel.desc(:run_at) # , where: { : :ascequel[:attempts] < max_attempts }
    end

    create_table(:inbox) do
      column :unique_id, :varchar, null: true, primary_key: true
      column :created_at, "timestamp without time zone", null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table(:outbox)
    drop_table(:outbox_with_group)
    drop_table(:inbox)
  end
end
