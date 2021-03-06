# == Schema Information
#
# Table name: mail_receivers
#
#  id          :integer          not null, primary key
#  address     :string(255)      not null
#  created_at  :datetime
#  updated_at  :datetime
#  user_id     :integer          not null
#  timezone    :string(255)      not null
#  locale_date :date             not null
#  notes_count :integer          default(0)
#

require 'securerandom'

class MailReceiver < ActiveRecord::Base
  validates :address     , presence: true
  validates :user        , presence: true
  validates :timezone    , presence: true
  validates :locale_date , presence: true

  belongs_to :user
  has_many :notes, -> { order :created_at }, {dependent: :destroy}

  pattr_writer :address

  after_initialize do
    self.address = SecureRandom.hex unless address
    self.timezone = user.timezone if not timezone and user
    refresh_locale_date if locale_date.nil?
  end

  def self.for user, **opts
    find_or_create_by user: user, locale_date: opts[:date] || current_date_in_timezone(user.timezone)
  end

  def self.current_date_in_timezone timezone
    Time.now.in_time_zone(timezone).to_date
  end

  def full_address
    "post+#{address}@#{Settings.server_name}"
  end

  def user= user
    if user.class == User
      write_attribute :user_id, user.id
      self.timezone = user.timezone
    else
      write_attribute :user_id, nil
      self.timezone = nil
    end
  end

  def timezone
    return unless identifier = read_attribute(:timezone)
    ActiveSupport::TimeZone[identifier]
  end

  private

  def refresh_locale_date
    return unless timezone
    self.locale_date = (created_at || Time.now).in_time_zone(timezone).to_date
  end

  def timezone= input_timezone
    if input_timezone.instance_of? ActiveSupport::TimeZone
      input_timezone = input_timezone.identifier
    end
    unless User.timezones.include? input_timezone
      input_timezone = nil
    end
    result = write_attribute :timezone, input_timezone
    refresh_locale_date
    result
  end
end
