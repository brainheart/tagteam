class UpdateExistingInputSourceMatching < ActiveRecord::Migration
  def up
    execute("UPDATE input_sources SET matching='any' WHERE matching IS NULL")
  end

  def down
  end
end
