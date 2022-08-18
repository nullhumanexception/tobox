# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:outbox) do
      primary_key :id
      column :type, :varchar, null: false
      column :data_before, :json, null: true
      column :data_after, :json, null: true
      column :created_at, :time, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end

  down do
    drop_table(:outbox)
  end
end
