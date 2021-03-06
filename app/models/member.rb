class Member < ActiveRecord::Base
  extend ActsAsTree::TreeView
  
  acts_as_tree order: "name", counter_cache: true

  belongs_to :user
  belongs_to :organization, counter_cache: true
  #belongs_to :invited_by, class_name: "Member", foreign_key: "parent_id"

  has_many :contacts
  has_many :orders
  has_many :rewards

  enum role: [ :member, :vip, :master, :angel, :partner ]
  #default_scope { where('user_id is not null') }

  def self.create_invite_code
    duration = self.duration_in_base62
    mapping ||= '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
    code = duration.map {|digit| mapping[digit].to_s }
    #code.shuffle.join
    code.join
  end
  
  def parent_name
    parent.nil? ? "" : parent.name
  end

  def invited_by_user
    parent.nil? ? nil : parent.user
  end

  def score_up_points
    level = organization.levels_for_scoring
    orders_for_scoring = Order.for_scoring(id)
    ids = Array.new
    ancestors.each do |m|
      scale = depth - m.depth
      if (scale <= level) && (m.user.member.angel?)
        rate = organization.rate[scale]
        orders_for_scoring.each do |order|
          r = Reward.create!(member_id:  m.id,
                              order_id:    order.id,
                              amount:      order.total,
                              rate:        rate,
                              points:      (order.total * rate / 100).to_i,
                              created_by:  user_id)
          m.points += r.points
          order.completed!
        end
        m.save
      end
    end
    ids
  end

  def following
    ids = Array.new
    level = organization.levels_for_scoring
    ancestors.each do |m|
      ids << m.id if depth - m.depth <= level
    end
    Member.where(id: ids)
  end

  def followers
    ids = Array.new
    level = organization.levels_for_scoring
    descendants.each do |m|
      ids << m.id if m.depth - depth <= level
    end
    Member.where(id: ids)
    #Member.includes("orders").includes("rewards").select("user_id, name, depth, ").where(id: ids)
  end

  def orders_with_points
    ids = Array.new
    ids << id
    level = organization.levels_for_scoring
    descendants.each do |m|
      ids << m.id if m.depth - depth <= level
    end
    Order.where(member_id: ids).order(created_at: :desc)
  end

  private
  	def self.epoch
  		Time.new(2015, 4, 15).utc
  	end

  	def self.duration_in_base62
  	  time = Time.now.utc
	    num = (time.to_i - self.epoch.to_i) * 1000000 + time.usec
      return [0] if num.zero?
      num = num.abs
      [].tap do |digits|
          while num > 0
            digits.unshift num % 62
            num /= 62
          end
      end
 	end
end
