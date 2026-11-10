class CreateLtiContexts < ActiveRecord::Migration[8.0]
  def change
    create_table :lti_contexts do |t|
      t.references :lti_consumer, null: false, foreign_key: true
      t.string :context_id, null: false
      t.string :title
      t.string :label

      t.timestamps
    end

    add_index :lti_contexts, %i[lti_consumer_id context_id], unique: true
  end
end
