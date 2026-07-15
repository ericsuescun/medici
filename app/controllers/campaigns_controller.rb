class CampaignsController < SecureApplicationController
  before_action :set_study, only: %i[ index new create ]
  before_action :set_campaign, only: %i[ show edit update destroy ]

  def index
    # Preload documents so the per-card count (campaign_documents.size) doesn't
    # fire one COUNT query per campaign.
    @campaigns = @study.campaigns.includes(:campaign_documents).order(created_at: :desc)
  end

  def show
    # Preload the attachments the show page links, avoiding an Active Storage N+1.
    @documents = @campaign.campaign_documents.with_attached_file
  end

  def new
    @campaign = @study.campaigns.build
  end

  def edit
  end

  def create
    @campaign = @study.campaigns.build(campaign_params)

    respond_to do |format|
      if @campaign.save
        format.html { redirect_to campaign_url(@campaign), notice: t("campaigns.created") }
        format.json { render :show, status: :created, location: @campaign }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @campaign.update(campaign_params)
        format.html { redirect_to campaign_url(@campaign), notice: t("campaigns.updated") }
        format.json { render :show, status: :ok, location: @campaign }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @campaign.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    study = @campaign.study
    @campaign.destroy!

    respond_to do |format|
      format.html { redirect_to study_campaigns_url(study), notice: t("campaigns.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    def set_study
      @study = Study.find(params[:study_id])
    end

    def set_campaign
      @campaign = Campaign.find(params[:id])
      @study = @campaign.study
    end

    def campaign_params
      permitted = params.require(:campaign).permit(
        :title, :description, :call_to_action, :status,
        :target_instagram, :target_facebook, :target_twitter,
        *Campaign::CREDENTIAL_FIELDS
      )
      # A blank secret field means "keep the stored one" — drop it so the empty
      # password input doesn't overwrite an existing encrypted credential.
      Campaign::SECRET_FIELDS.each do |field|
        permitted.delete(field) if permitted[field].blank?
      end
      permitted
    end
end
