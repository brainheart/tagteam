class InputSourceCreator
  attr_reader :input_source
  def initialize(attrs)
    @input_source = InputSource.new()
    @input_source.attributes = attrs
    if @input_source.item_source_type == 'Tag'
      @input_source.item_source_type = 'ActsAsTaggableOn::Tag'
    end

    @input_source.republished_feed_id = attrs[:republished_feed_id]
  end

  def save(current_user)
    result = @input_source.save
    current_user.has_role!(:owner, @input_source)
    current_user.has_role!(:creator, @input_source)
    result
  end
end
