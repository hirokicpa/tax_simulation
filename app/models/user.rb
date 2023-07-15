class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  require './app/uploaders/image_uploader'

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :questions
  has_many :answers
  mount_uploader :avatar, ImageUploader

  before_destroy :delete_questions
  
  def full_name
  "#{first_name} #{last_name}"
  end

  private

  def delete_questions
    self.delete_answers
    self.questions.destroy_all
  end

  def delete_answers
    self.answers.destroy_all
  end
end
