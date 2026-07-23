require 'rails_helper'

# `users.active` gates sign-in: an account an admin has not activated cannot get
# a session, and losing activation ends the session it already has.
RSpec.describe "Sign-in activation gate", type: :request do
  let(:password) { "12345678" }

  def sign_in_with(user)
    post user_session_path, params: { user: { email: user.email, password: password } }
  end

  it "refuses an inactive account and leaves it signed out" do
    user = FactoryBot.create(:user, :sponsor_rep, :inactive, password: password)

    sign_in_with(user)

    # The refusal is rendered by Devise::FailureApp, so assert the outcome:
    # bounced back to the sign-in page, with no session to show for it.
    expect(response).to redirect_to(new_user_session_path)

    get studies_path
    expect(response).not_to be_successful
  end

  it "lets an activated account sign in" do
    user = FactoryBot.create(:user, :sponsor_rep, password: password)

    sign_in_with(user)

    expect(response).to have_http_status(:redirect)
    expect(controller.current_user).to eq(user)
  end

  it "always lets an admin sign in, even if the column was flipped directly" do
    admin = FactoryBot.create(:user, :admin, password: password)
    admin.update_column(:active, false) # bypasses the force-active callback

    sign_in_with(admin)

    expect(controller.current_user).to eq(admin)
  end

  it "signs out a user who is deactivated mid-session" do
    user = FactoryBot.create(:user, :sponsor_rep, password: password)
    sign_in(user, scope: :user)

    get studies_path
    expect(response).to be_successful

    user.update!(active: false)

    get studies_path
    expect(response).to redirect_to(new_user_session_path)
  end
end
