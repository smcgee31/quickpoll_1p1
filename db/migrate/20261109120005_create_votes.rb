class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :poll, null: false, foreign_key: true
      t.references :lti_user, null: false, foreign_key: true
      t.integer :option_index, null: false

      t.timestamps
    end

    add_index :votes, %i[poll_id lti_user_id], unique: true
  end
end
