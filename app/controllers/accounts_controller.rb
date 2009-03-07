class AccountsController < ApplicationController
  before_filter :require_user
  before_filter "set_current_tab(:accounts)", :except => [ :new, :edit, :create, :update, :destroy ]

  # GET /accounts
  # GET /accounts.xml
  #----------------------------------------------------------------------------
  def index
    @accounts = Account.my(@current_user)
    make_new_account if context_exists?(:create_account)

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @accounts }
    end
  end

  # GET /accounts/1
  # GET /accounts/1.xml
  #----------------------------------------------------------------------------
  def show
    @account = Account.find(params[:id])
    @stage = Setting.opportunity_stage.inject({}) { |hash, item| hash[item.last] = item.first; hash }
    @comment = Comment.new

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @account }
    end
  end

  # GET /accounts/new
  # GET /accounts/new.xml                                                  AJAX
  #----------------------------------------------------------------------------
  def new
    make_new_account
    @context = save_context(:create_account)

    respond_to do |format|
      format.js   # new.js.rjs
      format.html # new.html.erb
      format.xml  { render :xml => @account }
    end
  end

  # GET /accounts/1/edit                                                   AJAX
  #----------------------------------------------------------------------------
  def edit
    @account = Account.find(params[:id])
    @users   = User.all_except(@current_user)
    @context = save_context(dom_id(@account))
    if params[:open] =~ /(\d+)\z/
      @previous = Account.find($1)
    end
  end

  # POST /accounts
  # POST /accounts.xml                                                     AJAX
  #----------------------------------------------------------------------------
  def create
    @account = Account.new(params[:account])
    @users = User.all_except(@current_user)
    @context = save_context(:create_account)

    respond_to do |format|
      if @account.save_with_permissions(params[:users])
        drop_context(@context)
        format.js   # create.js.rjs
        format.html { redirect_to(@account) }
        format.xml  { render :xml => @account, :status => :created, :location => @account }
      else
        format.js   # create.js.rjs
        format.html { render :action => "new" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /accounts/1
  # PUT /accounts/1.xml                                                    AJAX
  #----------------------------------------------------------------------------
  def update
    @account = Account.find(params[:id])

    respond_to do |format|
      if @account.update_attributes(params[:account])
        format.js
        format.html { redirect_to(@account) }
        format.xml  { head :ok }
      else
        @users = User.all_except(@current_user) # Need ir to redraw [Edit Account] form.
        format.js
        format.html { render :action => "edit" }
        format.xml  { render :xml => @account.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /accounts/1
  # DELETE /accounts/1.xml
  #----------------------------------------------------------------------------
  def destroy
    @account = Account.find(params[:id])
    @account.destroy

    respond_to do |format|
      format.js
      format.html { redirect_to(accounts_url) }
      format.xml  { head :ok }
    end
  end

  private
  #----------------------------------------------------------------------------
  def make_new_account
    @account = Account.new
    @users = User.all_except(@current_user)
    find_related_asset_for(@account)
  end


end
