# Allows non-authenticated users to see info about InputSources. Also allows RepublishedFeed and InputSource owners to modify / add / delete.  
class InputSourcesController < ApplicationController
  before_filter :load_input_source, :except => [:new, :create, :find]
  before_filter :load_republished_feed, :only => [:new, :create, :find]

  access_control do
    allow all, :to => [:show, :find]
    allow :owner, :of => :republished_feed, :to => [:new, :create, :edit, :update]
    allow :owner, :of => :input_source, :to => [:edit, :update, :destroy]
    allow :owner, :of => :hub
    allow :superadmin
  end

  def new
    @input_source = InputSource.new(params[:input_source])
    #ok because we're using ACL9 to protect this method.
    @input_source.republished_feed_id = params[:input_source][:republished_feed_id]
    respond_to do |format|
      format.html do
        if request.xhr?
          render :layout => nil
        end
      end
    end
  end

  def create
    @input_source_creator = InputSourceCreator.new(params[:input_source])
    @input_source = @input_source_creator.input_source
    respond_to do|format|
      if @input_source_creator.save(current_user)
        @message = (@input_source.effect == 'add') ? %Q|Added "#{@input_source.item_source}" to "#{@republished_feed}"| : %Q|Removed "#{@input_source.item_source}" from "#{@republished_feed}"|
        format.html{
          unless request.xhr?
            flash[:notice] = @message
            redirect_to hub_republished_feed_url(@hub,@republished_feed)
          else
            render :text => @message 
          end
        }
        format.js
      else
        @input_source = @input_source_creator.input_source
        Rails.logger.debug @input_source.inspect
        Rails.logger.debug @input_source.errors.inspect
        @message = %Q|Could not add that input source for the following reasons:<br />#{@input_source.errors.full_messages.join('<br/>')}|
        format.html {
          unless request.xhr?
            flash[:error] = @message
            render :action => :new
          else 
            render :text => @message, :status => :unprocessable_entity
          end
        }
        format.js {
          render :action => :new, :formats => [:js]
        }
      end
    end
  end

  def update
    @input_source.attributes = params[:input_source]
    if @input_source.item_source_type == 'Tag'
      @input_source.item_source_type = 'ActsAsTaggableOn::Tag'
    end
    respond_to do|format|
      if @input_source.save
        current_user.has_role!(:editor, @input_source)
        flash[:notice] = 'Updated that input source'
        format.html{redirect_to hub_republished_feed_url(@input_source.republished_feed.hub,@input_source.republished_feed)}
      else
        flash[:error] = 'Could not update that input source'
        format.html {render :action => :edit}
      end
    end
  end

  def find
    @search = Sunspot.new_search params[:search_in].collect{|f| f.constantize}
    params[:hub_id] = @republished_feed.hub_id  
    @hub = Hub.find(@republished_feed.hub_id)

    if params[:search_in].include?('Feed')
      @search.build do
        text_fields do
          any_of do
            with(:description).starting_with(params[:q])
            with(:title).starting_with(params[:q])
            with(:feed_url).starting_with(params[:q])
          end
        end
        with :hub_ids, params[:hub_id]
      end
    end

    if params[:search_in].include?('FeedItem')
      @search.build do
        text_fields do
          any_of do
            with(:title).starting_with(params[:q])
            with(:content).starting_with(params[:q])
            with(:url).starting_with(params[:q])
          end
        end
        with :hub_ids, params[:hub_id]
      end
    end

    if params[:search_in].include?('ActsAsTaggableOn::Tag')
      @search.build do
        text_fields do
          with(:name).starting_with(params[:q])
        end
        with :contexts, "hub_#{params[:hub_id]}"
      end
    end

    @search.execute

    respond_to do|format|
      format.html{
        if request.xhr?
          render :partial => 'shared/search_results/list', :object => @search, :layout => false
        else
          render
        end
      }
      format.json{ render :json => @search }
    end
  end

  def edit
  end

  def destroy
    begin
      @republished_feed = @input_source.republished_feed
      @hub = @republished_feed.hub
      @input_source.destroy
      flash[:notice] = 'Removed that item'
    rescue
      flash[:notice] = 'Could not remove that item'
    end
    redirect_to hub_republished_feed_url(@hub,@republished_feed)
  end

  def show
  end

  private

  def load_republished_feed
    republished_feed_id = (params[:input_source].blank?) ? params[:republished_feed_id] : params[:input_source][:republished_feed_id]
    @republished_feed = RepublishedFeed.find(republished_feed_id)
    @hub = @republished_feed.hub
  end

  def load_input_source
    @input_source = InputSource.find(params[:id])
  end

end
