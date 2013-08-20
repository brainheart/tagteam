# A RepublishedFeed (aka Remix) contains many InputSource objects that add and remove FeedItem objects. The end result of these additions and removals is an array of FeedItem objects found via the Sunspot search engine.
#
# A RepublishedFeed belongs to a Hub.
#
# Removals take precedence over additions.
# 
# Most validations are contained in the ModelExtensions mixin.
#
class RepublishedFeed < ActiveRecord::Base

  include AuthUtilities
  include ModelExtensions
  before_validation do
    auto_sanitize_html(:description)
  end

  acts_as_authorization_object
  acts_as_api do|c|
    c.allow_jsonp_callback = true
  end

  attr_accessible :title, :hub_id, :description, :limit, :url_key

  SORTS = ['date_published', 'title']
  SORTS_FOR_SELECT = [['Date Published','date_published' ],['Title', 'title']]

  belongs_to :hub
  has_many :input_sources, :dependent => :destroy, :order => 'created_at desc' 

  validates_uniqueness_of :url_key
  validates_format_of :url_key, :with => /^[a-z\d\-]+/

  api_accessible :default do |t|
    t.add :id
    t.add :title
    t.add :hub
    t.add :description
    t.add :created_at
    t.add :updated_at
    t.add :input_sources
  end

  # Create a set of arrays that define additions and removals to create a paginated Sunspot query.
  def item_search
    if input_sources.blank?
      return nil
    end

    # Use input sources to build search, must map ids
    search = FeedItem.search(:include => [:tags, :taggings, :feeds, :hub_feeds]) do
      any_of do
        unless input_feeds.blank?
          with(:feed_ids, input_feeds.collect(&:id))
        end
        unless input_feed_items.blank?
          with(:id, input_feed_items.collect(&:id))
        end
        unless input_tags.blank?
          with(:tag_contexts, input_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"})
        end
      end
      any_of do
        unless removal_feeds.blank?
          without(:feed_ids, removal_feeds.collect(&:id))
        end
        unless removal_feed_items.blank?
          without(:id, removal_feed_items.collect(&:id))
        end
        unless removal_tags.blank?
          without(:tag_contexts, removal_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"})
        end
      end
      order_by('date_published', :desc)
      paginate :per_page => self.limit, :page => 1
    end

    search

  end

  def to_s
    "#{title}"
  end

  def self.title
    'Remixed feed'
  end

  def input_tags
    @input_tags ||= input_sources.inputs.tags.map{ |i| i.item_source }
  end

  def removal_tags
    @removal_tals ||= input_sources.removals.tags.map{ |i| i.item_source }
  end

  def input_feeds
    @input_feeds ||= input_sources.inputs.feeds.map{ |i| i.item_source }
  end

  def removal_feeds
    @removal_feeds ||= input_sources.removals.feeds.map{ |i| i.item_source }
  end

  def input_feed_items
    @input_feed_items ||= input_sources.inputs.feed_items.map{ |i| i.item_source }
  end

  def removal_feed_items
    @removal_feed_items ||= input_sources.removals.feed_items.map{ |i| i.item_source }
  end

end
