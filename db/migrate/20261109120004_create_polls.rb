class CreatePolls < ActiveRecord::Migration[8.0]
  def change
    create_table :polls do |t|
      t.references :lti_context, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :lti_users }
      t.text :question, null: false
      t.jsonb :options, null: false, default: []

      t.timestamps
    end

    add_index :polls, %i[lti_context_id created_at]
  end
end
