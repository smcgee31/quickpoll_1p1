class CreateLtiUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :lti_users do |t|
      t.references :lti_consumer, null: false, foreign_key: true
      # LTI 1.1 "user_id" launch param
      t.string :lti1p1_user_id, null: false
      # LTI 1.3 "sub" claim. Stays null until the user launches through 1.3.
      t.string :lti1p3_sub
      t.string :name

      t.timestamps
    end

    add_index :lti_users, %i[lti_consumer_id lti1p1_user_id], unique: true
    add_index :lti_users, %i[lti_consumer_id lti1p3_sub], unique: true, where: "lti1p3_sub IS NOT NULL"
  end
end
