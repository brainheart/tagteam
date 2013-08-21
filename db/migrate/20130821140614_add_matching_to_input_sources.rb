class AddMatchingToInputSources < ActiveRecord::Migration
  def change
    add_column :input_sources, :matching, :string
  end
end
