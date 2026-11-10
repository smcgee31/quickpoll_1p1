class CreateUsedNonces < ActiveRecord::Migration[8.0]
  def change
    create_table :used_nonces do |t|
      t.references :lti_consumer, null: false, foreign_key: true
      t.string :nonce, null: false
      t.bigint :oauth_timestamp, null: false

      t.timestamps
    end

    add_index :used_nonces, %i[lti_consumer_id nonce], unique: true
    add_index :used_nonces, :oauth_timestamp
  end
end
