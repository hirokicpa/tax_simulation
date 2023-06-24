class Question < ApplicationRecord
  belongs_to :board
  belongs_to :user
  has_many :answers
  
  validates :title, presence: true, length: { maximum: 50 }
  validates :content, presence: true, length: { maximum: 200 }
end
