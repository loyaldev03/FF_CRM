require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe OpportunitiesController do

  def get_data_for_sidebar
    @stage = Setting.as_hash(:opportunity_stage)
  end

  before(:each) do
    require_user
    set_current_tab(:opportunities)
  end

  # GET /opportunities
  # GET /opportunities.xml
  #----------------------------------------------------------------------------
  describe "responding to GET index" do

    before(:each) do
      get_data_for_sidebar
    end

    it "should expose all opportunities as @opportunities and render [index] template" do
      @opportunities = [ Factory(:opportunity, :user => @current_user) ]

      get :index
      assigns[:opportunities].should == @opportunities
      response.should render_template("opportunities/index")
    end

    it "should expose the data for the opportunities sidebar" do
      get :index
      assigns[:stage].should == @stage
      (assigns[:opportunity_stage_total].keys - (@stage.keys << :all << :other)).should == []
    end

    it "should filter out opportunities by stage" do
      controller.session[:filter_by_opportunity_stage] = "prospecting,qualification"
      @opportunities = [
        Factory(:opportunity, :user => @current_user, :stage => "qualification"),
        Factory(:opportunity, :user => @current_user, :stage => "prospecting")
      ]
      # This one should be filtered out.
      Factory(:opportunity, :user => @current_user, :stage => "analysis")

      get :index
      # Note: can't compare opportunities directly because of BigDecimal objects.
      assigns[:opportunities].size.should == 2
      assigns[:opportunities].map(&:stage).should == %w(prospecting qualification)
    end

    describe "AJAX pagination" do
      it "should pick up page number from params" do
        @opportunities = [ Factory(:opportunity, :user => @current_user) ]
        xhr :get, :index, :page => 42

        assigns[:current_page].to_i.should == 42
        assigns[:opportunities].should == [] # page #42 should be empty if there's only one opportunity ;-)
        session[:opportunities_current_page].to_i.should == 42
        response.should render_template("opportunities/index")
      end

      it "should pick up saved page number from session" do
        session[:opportunities_current_page] = 42
        @opportunities = [ Factory(:opportunity, :user => @current_user) ]
        xhr :get, :index

        assigns[:current_page].should == 42
        assigns[:opportunities].should == []
        response.should render_template("opportunities/index")
      end
    end

    describe "with mime type of XML" do
      it "should render all opportunities as xml" do
        request.env["HTTP_ACCEPT"] = "application/xml"
        @opportunities = [ Factory(:opportunity, :user => @current_user) ]

        get :index
        response.body.should == @opportunities.to_xml
      end
    end

  end

  # GET /opportunities/1
  # GET /opportunities/1.xml
  #----------------------------------------------------------------------------
  describe "responding to GET show" do

    describe "with mime type of HTML" do

      before(:each) do
        @opportunity = Factory(:opportunity, :id => 42)
        @stage = Setting.as_hash(:opportunity_stage)
        @comment = Comment.new
      end

      it "should expose the requested opportunity as @opportunity and render [show] template" do
        get :show, :id => 42
        assigns[:opportunity].should == @opportunity
        assigns[:stage].should == @stage
        assigns[:comment].attributes.should == @comment.attributes
        response.should render_template("opportunities/show")
      end

      it "should update an activity when viewing the opportunity" do
        Activity.should_receive(:log).with(@current_user, @opportunity, :viewed).once
        get :show, :id => @opportunity.id
      end

    end

    describe "with mime type of XML" do

      it "should render the requested opportunity as xml" do
        @opportunity = Factory(:opportunity, :id => 42)
        @stage = Setting.as_hash(:opportunity_stage)

        request.env["HTTP_ACCEPT"] = "application/xml"
        get :show, :id => 42
        response.body.should == @opportunity.to_xml
      end

    end

  end

  # GET /opportunities/new
  # GET /opportunities/new.xml                                             AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET new" do

    it "should expose a new opportunity as @opportunity and render [new] template" do
      @opportunity = Opportunity.new(:user => @current_user, :access => "Private", :stage => "prospecting")
      @account = Account.new(:user => @current_user, :access => "Private")
      @users = [ Factory(:user) ]
      @accounts = [ Factory(:account, :user => @current_user) ]

      xhr :get, :new
      assigns[:opportunity].attributes.should == @opportunity.attributes
      assigns[:account].attributes.should == @account.attributes
      assigns[:users].should == @users
      assigns[:accounts].should == @accounts
      response.should render_template("opportunities/new")
    end

    it "should created an instance of related object when necessary" do
      @contact = Factory(:contact, :id => 42)

      xhr :get, :new, :related => "contact_42"
      assigns[:contact].should == @contact
    end

  end

  # GET /opportunities/1/edit                                              AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET edit" do

    it "should expose the requested opportunity as @opportunity and render [edit] template" do
      # Note: campaign => nil makes sure campaign factory is not invoked which has a side
      # effect of creating an extra (campaign) user.
      @opportunity = Factory(:opportunity, :id => 42, :user => @current_user, :campaign => nil)
      @account  = Account.new(:user => @current_user)
      @users = [ Factory(:user) ]
      @stage = Setting.as_hash(:opportunity_stage)
      @accounts = [ Factory(:account, :user => @current_user) ]

      xhr :get, :edit, :id => 42
      assigns[:opportunity].should == @opportunity
      assigns[:account].attributes.should == @account.attributes
      assigns[:accounts].should == @accounts
      assigns[:users].should == @users
      assigns[:stage].should == @stage
      assigns[:previous].should == nil
      response.should render_template("opportunities/edit")
    end

    it "should expose previous opportunity as @previous when necessary" do
      @opportunity = Factory(:opportunity, :id => 42)
      @previous = Factory(:opportunity, :id => 41)

      xhr :get, :edit, :id => 42, :previous => 41
      assigns[:previous].should == @previous
    end

  end

  # POST /opportunities
  # POST /opportunities.xml                                                AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST create" do

    describe "with valid params" do

      before(:each) do
        @opportunity = Factory.build(:opportunity, :user => @current_user)
        Opportunity.stub!(:new).and_return(@opportunity)
        @stage = Setting.as_hash(:opportunity_stage)
      end

      it "should expose a newly created opportunity as @opportunity and render [create] template" do
        xhr :post, :create, :opportunity => { :name => "Hello" }, :account => { :name => "Hello again" }, :users => %w(1 2 3)
        assigns(:opportunity).should == @opportunity
        assigns(:stage).should == @stage
        assigns(:opportunity_stage_total).should == nil # No sidebar data unless called from /opportunies page.
        response.should render_template("opportunities/create")
      end

      it "should get sidebar data if called from opportunities index" do
        request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        xhr :post, :create, :opportunity => { :name => "Hello" }, :account => { :name => "Hello again" }, :users => %w(1 2 3)
        assigns(:opportunity_stage_total).should be_an_instance_of(Hash)
      end

      it "should reload opportunities to update pagination if called from opportunities index" do
        request.env["HTTP_REFERER"] = "http://localhost/opportunities"

        xhr :post, :create, :opportunity => { :name => "Hello" }, :account => { :name => "Hello again" }, :users => %w(1 2 3)
        assigns[:opportunities].should == [ @opportunity ]
      end

      it "should associate opportunity with the campaign when called from campaign landing page" do
        @campaign = Factory(:campaign, :id => 42)

        request.env["HTTP_REFERER"] = "http://localhost/campaign/42"
        xhr :post, :create, :opportunity => { :name => "Hello" }, :campaign => 42, :account => {}, :users => []
        assigns(:opportunity).should == @opportunity
        @opportunity.campaign.should == @campaign
      end

      it "should associate opportunity with the contact when called from contact landing page" do
        @contact = Factory(:contact, :id => 42)

        request.env["HTTP_REFERER"] = "http://localhost/contact/42"
        xhr :post, :create, :opportunity => { :name => "Hello" }, :contact => 42, :account => {}, :users => []
        assigns(:opportunity).should == @opportunity
        @opportunity.contacts.should include(@contact)
        @contact.opportunities.should include(@opportunity)
      end

      it "should create new account and associate it with the opportunity" do
        xhr :put, :create, :opportunity => { :name => "Hello" }, :account => { :name => "new account" }
        assigns(:opportunity).should == @opportunity
        @opportunity.account.name.should == "new account"
      end

      it "should associate opportunity with the existing account" do
        @account = Factory(:account, :id => 42)

        xhr :post, :create, :opportunity => { :name => "Hello world" }, :account => { :id => 42 }, :users => []
        assigns(:opportunity).should == @opportunity
        @opportunity.account.should == @account
        @account.opportunities.should include(@opportunity)
      end

    end

    describe "with invalid params" do

      it "should expose a newly created but unsaved opportunity as @opportunity with blank @account and render [create] template" do
        @opportunity = Factory.build(:opportunity, :name => nil, :campaign => nil, :user => @current_user)
        Opportunity.stub!(:new).and_return(@opportunity)
        @stage = Setting.as_hash(:opportunity_stage)
        @users = [ Factory(:user) ]
        @account = Account.new(:user => @current_user)
        @accounts = [ Factory(:account, :user => @current_user) ]

        # Expect to redraw [create] form with blank account.
        xhr :post, :create, :opportunity => {}, :account => { :user_id => @current_user.id }
        assigns(:opportunity).should == @opportunity
        assigns(:users).should == @users
        assigns(:account).attributes.should == @account.attributes
        assigns(:accounts).should == @accounts
        response.should render_template("opportunities/create")
      end

      it "should expose a newly created but unsaved opportunity as @opportunity with existing @account and render [create] template" do
        @account = Factory(:account, :id => 42, :user => @current_user)
        @opportunity = Factory.build(:opportunity, :name => nil, :campaign => nil, :user => @current_user)
        Opportunity.stub!(:new).and_return(@opportunity)
        @stage = Setting.as_hash(:opportunity_stage)
        @users = [ Factory(:user) ]

        # Expect to redraw [create] form with selected account.
        xhr :post, :create, :opportunity => {}, :account => { :id => 42, :user_id => @current_user.id }
        assigns(:opportunity).should == @opportunity
        assigns(:users).should == @users
        assigns(:account).should == @account
        assigns(:accounts).should == [ @account ]
        response.should render_template("opportunities/create")
      end

      it "should preserve the campaign when called from campaign landing page" do
        @campaign = Factory(:campaign, :id => 42)

        request.env["HTTP_REFERER"] = "http://localhost/campaign/42"
        xhr :post, :create, :opportunity => { :name => nil }, :campaign => 42, :account => {}, :users => []
        assigns(:campaign).should == @campaign
        response.should render_template("opportunities/create")
      end

      it "should preserve the contact when called from contact landing page" do
        @contact = Factory(:contact, :id => 42)

        request.env["HTTP_REFERER"] = "http://localhost/contact/42"
        xhr :post, :create, :opportunity => { :name => nil }, :contact => 42, :account => {}, :users => []
        assigns(:contact).should == @contact
        response.should render_template("opportunities/create")
      end

    end

  end

  # PUT /opportunities/1
  # PUT /opportunities/1.xml                                               AJAX
  #----------------------------------------------------------------------------
  describe "responding to PUT udpate" do

    describe "with valid params" do

      it "should update the requested opportunity, expose it as @opportunity, and render [update] template" do
        @opportunity = Factory(:opportunity, :id => 42)
        @stage = Setting.as_hash(:opportunity_stage)

        xhr :put, :update, :id => 42, :opportunity => { :name => "Hello world" }, :account => {}, :users => %w(1 2 3)
        @opportunity.reload.name.should == "Hello world"
        assigns(:opportunity).should == @opportunity
        assigns(:stage).should == @stage
        assigns(:opportunity_stage_total).should == nil
        response.should render_template("opportunities/update")
      end

      it "should get sidebar data if called from opportunities index" do
        @oppportunity = Factory(:opportunity, :id => 42)

        request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        xhr :put, :update, :id => 42, :opportunity => { :name => "Hello world" }, :account => {}
        assigns(:opportunity_stage_total).should be_an_instance_of(Hash)
      end

      it "should be able to create an account and associate it with updated opportunity" do
        @opportunity = Factory(:opportunity, :id => 42)

        xhr :put, :update, :id => 42, :opportunity => { :name => "Hello" }, :account => { :name => "new account" }
        assigns[:opportunity].should == @opportunity
        @opportunity.account.should_not be_nil
        @opportunity.account.name.should == "new account"
      end

      it "should be able to create an account and associate it with updated opportunity" do
        @old_account = Factory(:account, :id => 111)
        @new_account = Factory(:account, :id => 999)
        @opportunity = Factory(:opportunity, :id => 42)
        Factory(:account_opportunity, :account => @old_account, :opportunity => @opportunity)

        xhr :put, :update, :id => 42, :opportunity => { :name => "Hello" }, :account => { :id => 999 }
        assigns[:opportunity].should == @opportunity
        @opportunity.account.should == @new_account
      end

      it "should update opportunity permissions when sharing with specific users" do
        @opportunity = Factory(:opportunity, :id => 42, :access => "Public")
        he  = Factory(:user, :id => 7)
        she = Factory(:user, :id => 8)

        xhr :put, :update, :id => 42, :opportunity => { :name => "Hello", :access => "Shared" }, :users => %w(7 8), :account => {}
        @opportunity.reload.access.should == "Shared"
        @opportunity.permissions.map(&:user_id).sort.should == [ 7, 8 ]
        assigns[:opportunity].should == @opportunity
      end

    end

    describe "with invalid params" do

      it "should not update the requested opportunity but still expose it as @opportunity, and render [update] template" do
        @opportunity = Factory(:opportunity, :id => 42, :name => "Hello people")

        xhr :put, :update, :id => 42, :opportunity => { :name => nil }, :account => {}
        @opportunity.reload.name.should == "Hello people"
        assigns(:opportunity).should == @opportunity
        assigns(:opportunity_stage_total).should == nil
        response.should render_template("opportunities/update")
      end

      it "should expose existing account as @account if selected" do
        @account = Factory(:account, :id => 99)
        @opportunity = Factory(:opportunity, :id => 42)
        Factory(:account_opportunity, :account => @account, :opportunity => @opportunity)

        xhr :put, :update, :id => 42, :opportunity => { :name => nil }, :account => { :id => 99 }
        assigns(:account).should == @account
      end

    end

  end

  # DELETE /opportunities/1
  # DELETE /opportunities/1.xml                                            AJAX
  #----------------------------------------------------------------------------
  describe "responding to DELETE destroy" do
    before(:each) do
      @opportunity = Factory(:opportunity, :user => @current_user)
    end

    describe "AJAX request" do
      it "should destroy the requested opportunity and render [destroy] template" do
        xhr :delete, :destroy, :id => @opportunity.id

        lambda { @opportunity.reload }.should raise_error(ActiveRecord::RecordNotFound)
        assigns(:opportunity_stage_total).should == nil
        response.should render_template("opportunities/destroy")
      end

      describe "when called from Opportunities index page" do
        before(:each) do
          request.env["HTTP_REFERER"] = "http://localhost/opportunities"
        end

        it "should get sidebar data if called from opportunities index" do
          xhr :delete, :destroy, :id => @opportunity.id
          assigns(:opportunity_stage_total).should be_an_instance_of(Hash)
        end

        it "should try previous page and render index action if current page has no opportunities" do
          session[:opportunities_current_page] = 42

          xhr :delete, :destroy, :id => @opportunity.id
          session[:opportunities_current_page].should == 41
          response.should render_template("opportunities/index")
        end

        it "should render index action when deleting last opportunity" do
          session[:opportunities_current_page] = 1

          xhr :delete, :destroy, :id => @opportunity.id
          session[:opportunities_current_page].should == 1
          response.should render_template("opportunities/index")
        end
      end

      describe "when called from related asset page" do
        it "should reset current page to 1" do
          request.env["HTTP_REFERER"] = "http://localhost/accounts/123"

          xhr :delete, :destroy, :id => @opportunity.id
          session[:opportunities_current_page].should == 1
          response.should render_template("opportunities/destroy")
        end
      end
    end

    describe "HTML request" do
      it "should redirect to Opportunities index when an opportunity gets deleted from its landing page" do
        delete :destroy, :id => @opportunity.id
        flash[:notice].should_not == nil
        response.should redirect_to(opportunities_path)
      end
    end

  end

  # GET /opportunities/search/query                                                AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET search" do
    before(:each) do
      @first  = Factory(:opportunity, :user => @current_user, :name => "The first one")
      @second = Factory(:opportunity, :user => @current_user, :name => "The second one")
      @opportunities = [ @first, @second ]
    end

    it "should perform lookup using query string and redirect to index" do
      xhr :get, :search, :query => "second"

      assigns[:opportunities].should == [ @second ]
      assigns[:current_query].should == "second"
      session[:opportunities_current_query].should == "second"
      response.should render_template("index")
    end

    describe "with mime type of XML" do
      it "should perform lookup using query string and render XML" do
        request.env["HTTP_ACCEPT"] = "application/xml"
        get :search, :query => "second?!"

        response.body.should == [ @second ].to_xml
      end
    end
  end

  # Ajax request to filter out list of opportunities.                      AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET filter" do

    it "should expose filtered opportunities as @opportunity and render [filter] template" do
      session[:filter_by_opportunity_stage] = "qualification,analysis"
      @opportunities = [ Factory(:opportunity, :stage => "prospecting", :user => @current_user) ]
      @stage = Setting.as_hash(:opportunity_stage)

      xhr :get, :filter, :stage => "prospecting"
      assigns(:opportunities).should == @opportunities
      assigns[:stage].should == @stage
      response.should be_a_success
      response.should render_template("opportunities/index")
    end

    it "should reset current page to 1" do
      @opportunities = []
      xhr :get, :filter, :status => "new"

      session[:opportunities_current_page].should == 1
    end

  end

end
