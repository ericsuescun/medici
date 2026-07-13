# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def new
    session[:study_id] = params[:study_id] if params[:study_id].present?
    @study = Study.find_by(id: session[:study_id])
    super
  end

  def create
    @study = Study.find_by(id: session[:study_id])

    # Ley 1581 de 2012 (Art. 6, 9): explicit, prior authorization to process
    # sensitive health data is a hard gate — no account is created (and therefore
    # no patient data is collected) until it is granted.
    unless data_processing_authorized?
      build_resource(sign_up_params)
      resource.errors.add(:data_processing_authorization,
                          "Debe autorizar el tratamiento de datos personales sensibles para registrarse.")
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
      return
    end

    build_resource(sign_up_params)
    # Patient owns its identity; build it up-front so the required `userable`
    # (delegated_type) exists at save time. Seed its (encrypted) email from the
    # sign-up email — Devise login still authenticates against User#email.
    resource.userable = Patient.new(email: resource.email)

    if resource.save
      @study.users << resource if @study
      # Persist the habeas-data authorization as an immutable, auditable record.
      Consent.record_ley_1581!(resource, ip_address: request.remote_ip)
      # If the study's sponsor is a foreign entity, the same authorization also
      # covers the cross-border transfer (Ley 1581 Art. 26) — record it distinctly.
      if @study&.international_sponsor?
        Consent.record_cross_border_transfer!(resource, ip_address: request.remote_ip)
      end
      session.delete(:study_id)

      sign_up(resource_name, resource)
      respond_with resource, location: after_sign_up_path_for(resource)
    else
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
    end
  end

  private

  def data_processing_authorized?
    ActiveModel::Type::Boolean.new.cast(params.dig(:user, :data_processing_authorization))
  end

  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
