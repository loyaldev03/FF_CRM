require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe "/leads/create.js.rjs" do
  include LeadsHelper

  before(:each) do
    login_and_assign
    assigns[:campaigns] = [ Factory(:campaign) ]
  end

  it "create (success): should hide [Create Lead] form and insert lead partial" do
    assigns[:lead] = Factory(:lead, :id => 42)
    render "leads/create.js.rjs"

    response.should have_rjs(:insert, :top) do |rjs|
      with_tag("li[id=lead_42]")
    end
    response.should include_text('$("lead_42").visualEffect("highlight"')
  end

  it "create (success): should update sidebar when called from leads page" do
    assigns[:lead] = Factory(:lead, :id => 42)
    assigns[:lead_status_total] = { :contacted => 1, :converted => 1, :new => 1, :rejected => 1, :other => 1, :all => 5 }
    request.env["HTTP_REFERER"] = "http://localhost/leads"
    render "leads/create.js.rjs"

    response.should have_rjs("sidebar") do |rjs|
      with_tag("div[id=filters]")
      with_tag("div[id=recently]")
    end
    response.should include_text('$("filters").visualEffect("shake"')
  end

  it "create (success): should update recently viewed items when called outside the leads (i.e. embedded)" do
    assigns[:lead] = Factory(:lead, :id => 42)
    assigns[:lead_status_total] = { :contacted => 1, :converted => 1, :new => 1, :rejected => 1, :other => 1, :all => 5 }
    request.env["HTTP_REFERER"] = "http://localhost/campaigns/123"
    render "leads/create.js.rjs"

    response.should have_rjs("recently") do |rjs|
      with_tag("div[class=caption]")
    end
  end

  it "create (failure): should re-render [create.html.haml] template in :create_lead div" do
    assigns[:lead] = Factory.build(:lead, :first_name => nil) # make it invalid
    assigns[:users] = [ Factory(:user) ]
  
    render "leads/create.js.rjs"
  
    response.should have_rjs("create_lead") do |rjs|
      with_tag("form[class=new_lead]")
    end
    response.should include_text('$("create_lead").visualEffect("shake"')

  end

end


