class PurchasesController < ApplicationController
  #  before_action :authenticate_user!, only: [:new ]
  # GET /purchases/1
  def show
    @purchase = Purchase.find(params[:id])
    if !@purchase.merchandise_id.nil? #If this is a donation do not look for merchandise
      loot      = Merchandise.find(@purchase.merchandise_id)
      @itemname = loot.name
      id        = loot.user_id
      @user     = User.find(id)
    end
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @purchase }
    end
  end
  # GET /purchases/new
  def new
    if params[:pricesold].present? # Donation being made
      @purchase = Purchase.new
    elsif params[:merchandise_id].present? #Purchase being made
      @merchandise = Merchandise.find(params[:merchandise_id])
      @purchase = @merchandise.purchases.new
    end
    if user_signed_in?
      if current_user.stripe_customer_token.present?
        @card     = @purchase.retrieve_customer_card(current_user)
        @last4    = @card.last4
        @expmonth = @card.exp_month
        @expyear  = @card.exp_year
      end
    end
  end
  # POST /purchases
  def create
    @purchase                      = Purchase.new(purchase_params)
    @purchase_mailer_hash          = { purchase: @purchase }
    @merchandise                   = Merchandise.find(@purchase.merchandise_id)
    @seller                        = User.find(@merchandise.user_id)
    @purchase_mailer_hash[:seller] = @seller

    case @merchandise.buttontype
    when 'Donate'
      assign_user_id
      case @purchase.save_payment_with_donation
      when true
        PurchaseMailer.with(@purchase_mailer_hash).donation_saved.deliver_later
        PurchaseMailer.with(@purchase_mailer_hash).donation_received.deliver_later
        flash[:notice] = "You successfully donated $" + @merchandise.price + " . Thank you for being a donor of " + @seller.name
        redirect_to user_profile_path(@seller.permalink)
      when false
        redirect_back fallback_location: request.referrer, notice: "Your order did not go through. Try again."
      end
    when 'Buy'
      assign_user_id
      case @purchase.save_payment_with_merchandise
      when true
        @purchase_mailer_hash[:merchandise] = @merchandise
        PurchaseMailer.with(@purchase_mailer_hash).purchase_saved.deliver_later
        PurchaseMailer.with(@purchase_mailer_hash).purchase_received.deliver_later
        attachments = @merchandise.get_non_empty_attachments
        attachments.each do |key,value|
          send_data_to_buyer key, value and return
        end
        flash[:notice] = "Your Purchase is successfull"
        redirect_to user_profile_path(@seller.permalink)
        #redirect_to user_profile_path(@seller.permalink)
      when false
        redirect_back fallback_location: request.referrer, notice: "Your order did not go through. Try again."
      end
    end
  end

  private

  def assign_user_id
    case user_signed_in?
    when true
      @purchase.user_id = current_user.id
      @purchase_mailer_hash[:user] = User.find(@purchase.user_id)
    when false
    end
  end


  def send_data_to_buyer name, value
    if value != nil
      send_data "#{value}" , filename: name, disposition: 'inline'
    end
  end

  #if @merchandise.audio.present? || @merchandise.graphic.present? || @merchandise.video.present? || @merchandise.merchpdf.present? || @merchandise.merchmobi.present? || @merchandise.merchepub.present? #Is this if statement really the way we want to code?
  #      #audio
  #  if @merchandise.audio.present?
  #    filename = @merchandise.audio.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.audio.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  #  #graphic
  #  if @merchandise.graphic.present?
  #    filename = @merchandise.graphic.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.graphic.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  #  #video
  #  if @merchandise.video.present?
  #    filename = @merchandise.video.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.video.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  #  #pdf
  #  if @merchandise.merchpdf.present?
  #    filename = @merchandise.merchpdf.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.merchpdf.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  #  #mobi
  #  if @merchandise.merchmobi.present?
  #    filename = @merchandise.merchmobi.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.merchmobi.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  #  #epub
  #  if @merchandise.merchepub.present?
  #    filename = @merchandise.merchepub.to_s.split('/')
  #    filename = filename[filename.length-1]
  #    data = open("#{@merchandise.merchepub.to_s}")
  #    send_data data.read, filename: filename, disposition: 'attachment'
  #  end
  # end
  # end

  def purchase_params
    params.require(:purchase).permit(:stripe_customer_token, :bookfiletype,
                                     :groupcut, :shipaddress, :book_id,
                                     :stripe_card_token,:pricesold, :user_id,
                                     :author_id, :merchandise_id, :group_id,
                                     :email)
  end

end
