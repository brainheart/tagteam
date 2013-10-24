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

  attr_accessible :title, :hub_id, :description, :limit, :url_key, :search_term

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
      with(:feed_ids).any_of(any_input_feeds.collect(&:id)) unless any_input_feeds.blank?
      with(:id).any_of(any_input_feed_items.collect(&:id)) unless any_input_feed_items.blank?
      with(:tag_contexts).any_off(any_input_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"}) unless any_input_tags.blank?

      without(:feed_ids).any_of(any_removal_feeds.collect(&:id)) unless any_removal_feeds.blank?
      without(:id).any_of(any_removal_feed_items.collect(&:id)) unless any_removal_feed_items.blank?
      without(:tag_contexts).any_of(any_removal_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"}) unless any_removal_tags.blank?

      with(:feed_ids).all_of(all_input_feeds.collect(&:id)) unless all_input_feeds.blank?
      with(:id).all_of(all_input_feed_items.collect(&:id)) unless all_input_feed_items.blank?
      with(:tag_contexts).all_of(all_input_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"}) unless all_input_tags.blank?

      without(:feed_ids).all_of(all_removal_feeds.collect(&:id)) unless all_removal_feeds.blank?
      without(:id).all_of(all_removal_feed_items.collect(&:id)) unless all_removal_feed_items.blank?
      without(:tag_contexts).all_of(all_removal_tags.collect{|t| "hub_#{self.hub_id}-#{t.name}"}) unless all_removal_tags.blank?

      unless search_term.blank?
        fulltext search_term
        adjust_solr_params do |params|
          params[:q].gsub! '#', "tag_contexts_sm:hub_#{self.hub_id}-"
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

  def all_input_tags
    @all_input_tags ||= input_sources.match_all.inputs.tags.map{ |i| i.item_source }
  end

  def all_removal_tags
    @all_removal_tals ||= input_sources.match_all.removals.tags.map{ |i| i.item_source }
  end

  def all_input_feeds
    @all_input_feeds ||= input_sources.match_all.inputs.feeds.map{ |i| i.item_source }
  end

  def all_removal_feeds
    @all_removal_feeds ||= input_sources.match_all.removals.feeds.map{ |i| i.item_source }
  end

  def all_input_feed_items
    @all_input_feed_items ||= input_sources.match_all.inputs.feed_items.map{ |i| i.item_source }
  end

  def all_removal_feed_items
    @all_removal_feed_items ||= input_sources.match_all.removals.feed_items.map{ |i| i.item_source }
  end

  def any_input_tags
    @any_input_tags ||= input_sources.match_any.inputs.tags.map{ |i| i.item_source }
  end

  def any_removal_tags
    @any_removal_tals ||= input_sources.match_any.removals.tags.map{ |i| i.item_source }
  end

  def any_input_feeds
    @any_input_feeds ||= input_sources.match_any.inputs.feeds.map{ |i| i.item_source }
  end

  def any_removal_feeds
    @any_removal_feeds ||= input_sources.match_any.removals.feeds.map{ |i| i.item_source }
  end

  def any_input_feed_items
    @any_input_feed_items ||= input_sources.match_any.inputs.feed_items.map{ |i| i.item_source }
  end

  def any_removal_feed_items
    @any_removal_feed_items ||= input_sources.match_any.removals.feed_items.map{ |i| i.item_source }
  end

end
