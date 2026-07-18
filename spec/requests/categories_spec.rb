require 'rails_helper'

RSpec.describe "Categories admin", type: :request do
  describe "as an admin" do
    before { sign_in(FactoryBot.create(:user, :admin), scope: :user) }

    it "lists categories with their study counts and shows the navbar entry" do
      category = FactoryBot.create(:category, name: "Cardiología")
      category.studies << FactoryBot.create(:study)

      get categories_path

      expect(response).to be_successful
      expect(response.body).to include("Cardiología")
      expect(response.body).to include('href="/categories"')
    end

    it "creates a category" do
      expect {
        post categories_path, params: { category: { name: "Toxicología" } }
      }.to change(Category, :count).by(1)
      expect(response).to redirect_to(categories_path)
    end

    it "rejects a duplicate name" do
      FactoryBot.create(:category, name: "Cardiología")

      post categories_path, params: { category: { name: "Cardiología" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "renames a category" do
      category = FactoryBot.create(:category, name: "Cardio")

      patch category_path(category), params: { category: { name: "Cardiología" } }

      expect(category.reload.name).to eq("Cardiología")
    end

    it "deletes a category, keeping its studies" do
      category = FactoryBot.create(:category)
      study = FactoryBot.create(:study)
      category.studies << study

      expect {
        delete category_path(category)
      }.to change(Category, :count).by(-1)
      expect(Study.exists?(study.id)).to be(true)
      expect(study.reload.categories).to be_empty
    end
  end

  describe "as a trial centre rep" do
    before do
      rep = FactoryBot.create(:trial_center_branch_rep)
      sign_in(FactoryBot.create(:user, userable: rep), scope: :user)
    end

    it "is denied access to the categories admin" do
      get categories_path
      expect(response).to have_http_status(:redirect)
    end

    it "cannot create a category" do
      expect {
        post categories_path, params: { category: { name: "Nope" } }
      }.not_to change(Category, :count)
    end

    it "does not see the navbar entry" do
      get studies_path
      expect(response).to be_successful
      expect(response.body).not_to include('href="/categories"')
    end
  end
end
