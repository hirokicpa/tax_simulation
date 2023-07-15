class ChangeUserIdToBigintInQuestions < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        change_column :questions, :user_id, :bigint
      end
  
      dir.down do
        change_column :questions, :user_id, :integer
      end
    end
  end

end

