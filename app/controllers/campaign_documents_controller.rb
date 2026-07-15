class CampaignDocumentsController < SecureApplicationController
  before_action :set_campaign, only: :create
  before_action :set_document, only: :destroy

  # Adding a document requires can_edit on CampaignDocument (auto-authorized by
  # ResourceAuthorization); deleting one requires can_delete.
  def create
    @document = @campaign.campaign_documents.build(document_params)

    if @document.save
      redirect_to campaign_url(@campaign), notice: t("campaign_documents.created")
    else
      redirect_to campaign_url(@campaign), alert: @document.errors.full_messages.to_sentence
    end
  end

  def destroy
    campaign = @document.campaign
    @document.destroy!
    redirect_to campaign_url(campaign), notice: t("campaign_documents.destroyed")
  end

  private
    def set_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def set_document
      @document = CampaignDocument.find(params[:id])
    end

    def document_params
      params.require(:campaign_document).permit(:title, :document_type, :external_url, :file)
    end
end
