# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  def new
    session[:study_id] = params[:study_id] if params[:study_id].present?
    super
  end

  def create
    super do |resource|
      if session[:study_id].present?
        study = Study.find_by(id: session[:study_id])
        if study
          # Patient owns its identity now; seed its (encrypted) email from the
          # sign-up email so the record isn't identity-less. Devise login still
          # authenticates against User#email.
          new_patient = Patient.create!(email: resource.email)
          resource.userable = new_patient
          study.users << resource
          # Ensure the user has a Patient profile via delegated_type
          unless resource.patient?
            patient_profile = Patient.create!(email: resource.email)
            resource.update(userable: patient_profile)
          end
          # Aquí puedes asociar el study al nuevo usuario
          # study.update(user: resource)
        end
        session.delete(:study_id)
      end
    end
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
