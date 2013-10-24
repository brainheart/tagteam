class AddSearchTermToRepublishedFeeds < ActiveRecord::Migration
  def change
    add_column :republished_feeds, :search_term, :string
  end
end
