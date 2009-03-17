require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ContactsController do

  before(:each) do
    require_user
    set_current_tab(:contacts)
  end

  # GET /contacts
  # GET /contacts.xml
  #----------------------------------------------------------------------------
  describe "responding to GET index" do

    it "should expose all contacts as @contacts and render [index] template" do
      @contacts = [ Factory(:contact, :user => @current_user) ]

      get :index
      assigns[:contacts].should == @contacts
      response.should render_template("contacts/index")
    end

    describe "with mime type of xml" do

      it "should render all contacts as xml" do
        @contacts = [ Factory(:contact, :user => @current_user) ]

        request.env["HTTP_ACCEPT"] = "application/xml"
        get :index
        response.body.should == @contacts.to_xml
      end

    end

  end

  # GET /contacts/1
  # GET /contacts/1.xml
  #----------------------------------------------------------------------------
  describe "responding to GET show" do

    it "should expose the requested contact as @contact" do
      @contact = Factory(:contact, :id => 42)
      @stage = Setting.as_hash(:opportunity_stage)
      @comment = Comment.new

      get :show, :id => 42
      assigns[:contact].should == @contact
      assigns[:stage].should == @stage
      assigns[:comment].attributes.should == @comment.attributes
      response.should render_template("contacts/show")
    end

    describe "with mime type of xml" do

      it "should render the requested contact as xml" do
        @contact = Factory(:contact, :id => 42)

        request.env["HTTP_ACCEPT"] = "application/xml"
        get :show, :id => 42
        response.body.should == @contact.to_xml
      end

    end

  end

  # GET /contacts/new
  # GET /contacts/new.xml                                                  AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET new" do

    it "should expose a new contact as @contact and render [new] template" do
      @contact = Contact.new(:user => @current_user)
      @account = Account.new(:user => @current_user)
      @users = [ Factory(:user) ]
      @accounts = [ Factory(:account, :user => @current_user) ]

      xhr :get, :new
      assigns[:contact].attributes.should == @contact.attributes
      assigns[:account].attributes.should == @account.attributes
      assigns[:users].should == @users
      assigns[:accounts].should == @accounts
      assigns[:opportunity].should == nil
      response.should render_template("contacts/new")
    end

    it "should created an instance of related object when necessary" do
      @opportunity = Factory(:opportunity, :id => 42)

      xhr :get, :new, :related => "opportunity_42"
      assigns[:opportunity].should == @opportunity
    end

  end

  # GET /contacts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET edit" do

    it "should expose the requested contact as @contact and render [edit] template" do
      @contact = Factory(:contact, :id => 42, :user => @current_user, :lead => nil)
      @users = [ Factory(:user) ]
      @account = Account.new

      xhr :get, :edit, :id => 42
      assigns[:contact].should == @contact
      assigns[:users].should == @users
      assigns[:account].attributes.should == @account.attributes
      assigns[:previous].should == nil
      response.should render_template("contacts/edit")
    end

    it "should expose previous contact as @previous when necessary" do
      @contact = Factory(:contact, :id => 42)
      @previous = Factory(:contact, :id => 1992)

      xhr :get, :edit, :id => 42, :previous => 1992
      assigns[:previous].should == @previous
    end

  end

  # POST /contacts
  # POST /contacts.xml                                                     AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST create" do

    describe "with valid params" do

      it "should expose a newly created contact as @contact and render [create] template" do
        @contact = Factory.build(:contact, :first_name => "Billy", :last_name => "Bones")
        Contact.stub!(:new).and_return(@contact)

        xhr :post, :create, :contact => { :first_name => "Billy", :last_name => "Bones" }, :account => { :name => "Hello world" }, :users => %w(1 2 3)
        assigns(:contact).should == @contact
        response.should render_template("contacts/create")
      end

    end

    describe "with invalid params" do

      # Expect to redraw [create] form with blank account.
      it "should expose a newly created but unsaved contact as @contact with blank account and still render [create] template" do
        @contact = Factory.build(:contact, :first_name => nil, :user => @current_user, :lead => nil)
        Contact.stub!(:new).and_return(@contact)
        @users = [ Factory(:user) ]
        @accounts = [ Factory(:account, :user => @current_user) ]
        @account = Account.new(:user => @current_user)

        # This redraws [create] form with blank account.
        xhr :post, :create, :contact => { :first_name => nil }, :account => { :name => nil, :user_id => @current_user.id }
        assigns(:contact).should == @contact
        assigns(:users).should == @users
        assigns(:account).attributes.should == @account.attributes
        assigns(:accounts).should == @accounts
        response.should render_template("contacts/create")
      end

      # Expect to redraw [create] form with selected account.
      it "should expose a newly created but unsaved contact as @contact with selected account and still render [create] template" do
        @account = Factory(:account, :id => 42, :user => @current_user)
        @contact = Factory.build(:contact, :first_name => nil, :user => @current_user, :lead => nil)
        Contact.stub!(:new).and_return(@contact)
        @users = [ Factory(:user) ]

        # This redraws [create] form with blank account.
        xhr :post, :create, :contact => {}, :account => { :id => 42, :user_id => @current_user.id }
        assigns(:contact).should == @contact
        assigns(:users).should == @users
        assigns(:account).should == @account
        assigns(:accounts).should == [ @account ]
        response.should render_template("contacts/create")
      end

      # Expect to redraw [create] form with previously saved opportunity.
      it "should expose a newly created but unsaved contact as @contact with existing opportunity" do
        @opportunity = Factory(:opportunity, :id => 42, :user => @current_user)
        @contact = Factory.build(:contact, :first_name => nil, :user => @current_user, :lead => nil)
        Contact.stub!(:new).and_return(@contact)
        @users = [ Factory(:user) ]
        @account = Factory(:account, :id => 42, :user => @current_user)

        # This redraws [create] form with previously saved opportunity.
        xhr :post, :create, :contact => {}, :opportunity => 42, :account => { :id => 42, :user_id => @current_user.id }
        assigns(:contact).should == @contact
        assigns(:opportunity).should == @opportunity
        response.should render_template("contacts/create")
      end

    end

  end

  # PUT /contacts/1
  # PUT /contacts/1.xml                                                    AJAX
  #----------------------------------------------------------------------------
  describe "responding to PUT udpate" do

    describe "with valid params" do

      it "should update the requested contact and render [update] template" do
        @contact = Factory(:contact, :id => 42, :first_name => "Billy")

        xhr :put, :update, :id => 42, :contact => { :first_name => "Bones" }
        @contact.reload.first_name.should == "Bones"
        assigns(:contact).should == @contact
        response.should render_template("contacts/update")
      end

    end

    describe "with invalid params" do

      it "should not update the requested contact, but still expose it as @contact amd render [update] template" do
        @contact = Factory(:contact, :id => 42, :first_name => "Billy")

        xhr :put, :update, :id => 42, :contact => { :first_name => nil }
        @contact.reload.first_name.should == "Billy"
        assigns(:contact).should == @contact
        response.should render_template("contacts/update")
      end

    end

  end

  # DELETE /contacts/1
  # DELETE /contacts/1.xml                                                 AJAX
  #----------------------------------------------------------------------------
  describe "responding to DELETE destroy" do

    it "should destroy the requested contact and render [destroy] template" do
      @contact = Factory(:contact, :id => 42)

      xhr :delete, :destroy, :id => 42
      lambda { @contact.reload }.should raise_error(ActiveRecord::RecordNotFound)
      response.should render_template("contacts/destroy")
    end

  end

end
