# The MessagesController is the RESTful interface to Message objects

module Api
  class MessagesController < ApiController
    before_action :authorize

    before_action :check_api_writable, :only => [:create, :update, :destroy]
    before_action :check_api_readable, :except => [:create, :update, :destroy]

    authorize_resource

    around_action :api_call_handle_error, :api_call_timeout

    before_action :set_request_formats

    def inbox
      @skip_body = true
      @messages = Message.includes(:sender, :recipient).where(:to_user_id => current_user.id)

      show_messages
    end

    def outbox
      @skip_body = true
      @messages = Message.includes(:sender, :recipient).where(:from_user_id => current_user.id)

      show_messages
    end

    # Dump the details on a message given in params[:id]
    def show
      @message = Message.includes(:sender, :recipient).find(params[:id])

      raise OSM::APIAccessDenied if current_user.id != @message.from_user_id && current_user.id != @message.to_user_id

      # Render the result
      respond_to do |format|
        format.xml
        format.json
      end
    end

    # Create a new message from current user
    def create
      # Check the arguments are sane
      raise OSM::APIBadUserInput, "No title was given" if params[:title].blank?
      raise OSM::APIBadUserInput, "No body was given" if params[:body].blank?

      # Extract the arguments
      if params[:recipient_id]
        recipient_id = params[:recipient_id].to_i
        recipient = User.find(recipient_id)
      elsif params[:recipient]
        recipient_display_name = params[:recipient]
        recipient = User.find_by(:display_name => recipient_display_name)
      else
        raise OSM::APIBadUserInput, "No recipient was given"
      end

      raise OSM::APIRateLimitExceeded if current_user.sent_messages.where(:sent_on => Time.now.utc - 1.hour..).count >= current_user.max_messages_per_hour

      @message = Message.new(:sender => current_user,
                             :recipient => recipient,
                             :sent_on => Time.now.utc,
                             :title => params[:title],
                             :body => params[:body],
                             :body_format => "markdown")
      @message.save!

      UserMailer.message_notification(@message).deliver_later if @message.notify_recipient?

      # Return a copy of the new message
      respond_to do |format|
        format.xml { render :action => :show }
        format.json { render :action => :show }
      end
    end

    # Update read status of a message
    def update
      @message = Message.find(params[:id])
      read_status_idx = %w[true false].index params[:read_status]

      raise OSM::APIBadUserInput, "Invalid value of `read_status` was given" if read_status_idx.nil?
      raise OSM::APIAccessDenied unless current_user.id == @message.to_user_id

      @message.message_read = read_status_idx.zero?
      @message.save!

      # Return a copy of the message
      respond_to do |format|
        format.xml { render :action => :show }
        format.json { render :action => :show }
      end
    end

    # Delete message by marking it as not visible for the current user
    def destroy
      @message = Message.find(params[:id])
      if current_user.id == @message.from_user_id
        @message.from_user_visible = false
      elsif current_user.id == @message.to_user_id
        @message.to_user_visible = false
      else
        raise OSM::APIAccessDenied
      end

      @message.save!

      # Return a copy of the message
      respond_to do |format|
        format.xml { render :action => :show }
        format.json { render :action => :show }
      end
    end

    private

    def show_messages
      @messages = @messages.where(:muted => false)
      if params[:order].nil? || params[:order] == "newest"
        @messages = @messages.where(:id => ..params[:from_id]) unless params[:from_id].nil?
        @messages = @messages.order(:id => :desc)
      elsif params[:order] == "oldest"
        @messages = @messages.where(:id => params[:from_id]..) unless params[:from_id].nil?
        @messages = @messages.order(:id => :asc)
      else
        raise OSM::APIBadUserInput, "Invalid order specified"
      end

      limit = params[:limit]
      if !limit
        limit = Settings.default_message_query_limit
      elsif !limit.to_i.positive? || limit.to_i > Settings.max_message_query_limit
        raise OSM::APIBadUserInput, "Messages limit must be between 1 and #{Settings.max_message_query_limit}"
      else
        limit = limit.to_i
      end

      @messages = @messages.limit(limit)

      # Render the result
      respond_to do |format|
        format.xml
        format.json
      end
    end
  end
end
