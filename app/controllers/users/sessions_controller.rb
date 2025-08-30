# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  def new
    session[:study_id] = params[:study_id] if params[:study_id].present?
    super
  end

  # POST /resource/sign_in
  def create
    super do |resource|
      if session[:study_id].present?
        study = Study.find_by(id: session[:study_id])
        if study && !resource.studies.include?(study)
          study.users << resource
          # Ensure the user has a Patient profile via delegated_type
          unless resource.patient?
            patient_profile = Patient.create!
            resource.update(userable: patient_profile)
          end
          flash[:notice] = "Te has registrado exitosamente para participar en el estudio: #{study.short_title}"
        end
        session.delete(:study_id)
      end
    end
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
