module Events
  class EmailsController < ApplicationController
    before_action :authenticate_user!, :validate_organizer!, :find_event

    def new
      new_email = @event.event_emails.build(attendee_group: 'All')
      @email = EventEmailPresenter.new(new_email)
      @past_emails = PastEventEmailsPresenter.new(@event)
    end

    def create
      recipient_ids = email_params[:recipients] ? email_params[:recipients].map(&:to_i) : []
      recipient_rsvps = @event.rsvps.where(user_id: recipient_ids).includes(:user)

      cc_recipients = email_params[:cc_organizers] ? @event.organizers.map(&:email) : [current_user.email]

      @email = @event.event_emails.build(
        subject: email_params[:subject],
        body: email_params[:body],
        sender: current_user,
        recipient_rsvp_ids: recipient_rsvps.map(&:id),
        attendee_group: email_params[:attendee_group].to_i
      )

      unless @email.valid?
        @email = EventEmailPresenter.new(@email)
        @past_emails = PastEventEmailsPresenter.new(@event)
        flash[:alert] = "We were unable to send your email."
        return render :new
      end

      EventMailer.from_organizer(
        sender: current_user,
        recipients: recipient_rsvps.map { |rsvp| rsvp.user.email },
        cc: cc_recipients,
        subject: email_params[:subject],
        body: email_params[:body],
        event: @event
      ).deliver_now

      @email.save!

      redirect_to event_organizer_tools_path(@event), notice: <<-EOT
        Your email has been sent. Woo!
      EOT
    end

    def show
      @email = @event.event_emails.find(params[:id])
    end

    private

    def email_params
      params.require(:event_email)
    end

    def find_event
      @event = Event.find_by_id(params[:event_id])
    end
  end
end
