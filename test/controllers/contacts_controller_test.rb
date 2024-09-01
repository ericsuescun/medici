require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @contact = contacts(:one)
  end

  test "should get index" do
    get contacts_url
    assert_response :success
  end

  test "should get new" do
    get new_contact_url
    assert_response :success
  end

  test "should create contact" do
    assert_difference("Contact.count") do
      post contacts_url, params: { contact: { address1: @contact.address1, address2: @contact.address2, comments: @contact.comments, email1: @contact.email1, email2: @contact.email2, firstname: @contact.firstname, lastname: @contact.lastname, number1: @contact.number1, number2: @contact.number2, studies_id: @contact.studies_id, title1: @contact.title1, title2: @contact.title2, url: @contact.url } }
    end

    assert_redirected_to contact_url(Contact.last)
  end

  test "should show contact" do
    get contact_url(@contact)
    assert_response :success
  end

  test "should get edit" do
    get edit_contact_url(@contact)
    assert_response :success
  end

  test "should update contact" do
    patch contact_url(@contact), params: { contact: { address1: @contact.address1, address2: @contact.address2, comments: @contact.comments, email1: @contact.email1, email2: @contact.email2, firstname: @contact.firstname, lastname: @contact.lastname, number1: @contact.number1, number2: @contact.number2, studies_id: @contact.studies_id, title1: @contact.title1, title2: @contact.title2, url: @contact.url } }
    assert_redirected_to contact_url(@contact)
  end

  test "should destroy contact" do
    assert_difference("Contact.count", -1) do
      delete contact_url(@contact)
    end

    assert_redirected_to contacts_url
  end
end
