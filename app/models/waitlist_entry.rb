# frozen_string_literal: true

class WaitlistEntry < ApplicationRecord
  validates :email, presence: true, uniqueness: { case_sensitive: false }
end
