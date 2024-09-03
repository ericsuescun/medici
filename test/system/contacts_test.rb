require "application_system_test_case"

class ContactsTest < ApplicationSystemTestCase
  setup do
    @contact = contacts(:one)
  end

  test "visiting the index" do
    visit contacts_url
    assert_selector "h1", text: "Contacts"
  end

  test "should create contact" do
    visit contacts_url
    click_on "New contact"

    fill_in "Address1", with: @contact.address1
    fill_in "Comments", with: @contact.comments
    fill_in "Email1", with: @contact.email1
    fill_in "Firstname", with: @contact.firstname
    fill_in "Lastname", with: @contact.lastname
    fill_in "Number1", with: @contact.number1
    fill_in "Studies", with: @contact.studies_id
    fill_in "Title1", with: @contact.title1
    fill_in "Url", with: @contact.url
    click_on "Create Contact"

    assert_text "Contact was successfully created"
    click_on "Back"
  end

  test "should update Contact" do
    visit contact_url(@contact)
    click_on "Edit this contact", match: :first

    fill_in "Address1", with: @contact.address1
    fill_in "Comments", with: @contact.comments
    fill_in "Email1", with: @contact.email1
    fill_in "Firstname", with: @contact.firstname
    fill_in "Lastname", with: @contact.lastname
    fill_in "Number1", with: @contact.number1
    fill_in "Studies", with: @contact.studies_id
    fill_in "Title1", with: @contact.title1
    fill_in "Url", with: @contact.url
    click_on "Update Contact"

    assert_text "Contact was successfully updated"
    click_on "Back"
  end

  test "should destroy Contact" do
    visit contact_url(@contact)
    click_on "Destroy this contact", match: :first

    assert_text "Contact was successfully destroyed"
  end
end
