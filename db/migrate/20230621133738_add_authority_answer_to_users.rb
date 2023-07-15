class AddAuthorityAnswerToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :authority_answer, :boolean, default: false
  end
end
