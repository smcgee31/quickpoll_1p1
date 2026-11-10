class CreateLtiConsumers < ActiveRecord::Migration[8.0]
  def change
    create_table :lti_consumers do |t|
      t.string :name, null: false
      t.string :consumer_key, null: false
      t.string :shared_secret, null: false
      # tool_consumer_instance_guid from the launch. Set on first launch.
      t.string :instance_guid

      t.timestamps
    end

    add_index :lti_consumers, :consumer_key, unique: true
  end
end
