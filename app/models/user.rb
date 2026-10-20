# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  encrypts :google_access_token, :google_refresh_token

  has_one :profile, class_name: "UserProfile", dependent: :destroy
  has_one :body_measurement, dependent: :destroy
  has_many :garments, dependent: :destroy
  has_many :intake_batches, dependent: :destroy
  has_many :garment_drafts, dependent: :destroy
  has_many :week_plans, dependent: :destroy
  has_many :ai_calls, dependent: :nullify

  after_create :ensure_profile!

  validates :time_zone, presence: true
  validates :password, length: { in: 8..72 }, allow_nil: true

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.email = auth.info.email
      user.name ||= auth.info.name
      user.password = Devise.friendly_token[0, 20] if user.new_record? && user.encrypted_password.blank?
    end
  end

  def onboarding_complete?
    onboarding_completed_at.present?
  end

  def gender_label
    profile&.gender&.humanize
  end

  private

  def ensure_profile!
    create_profile! unless profile
  end
end
