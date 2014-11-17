require 'spec_helper'

describe Spree::ReturnAuthorization, type: :model do

  it { should have_one :avalara_transaction }
  let(:user) { FactoryGirl.create(:user) }
  let(:address) { FactoryGirl.create(:address) }

  before :each do
    MyConfigPreferences.set_preferences
    @stock_location = FactoryGirl.create(:stock_location)
    @order = FactoryGirl.create(:shipped_order)
    @order.shipment_state = "shipped"
    @order.line_items.each do |line_item|
      line_item.tax_category.update_attributes(name: "Clothing", description: "PC030000")
    end
    @inventory_unit = @order.shipments.first.inventory_units.first
    @variant = @order.variants.first
    @return_authorization = Spree::ReturnAuthorization.create(:order => @order, :stock_location_id => @stock_location.id)
  end

  describe "#avalara_eligible" do
    it "should return true" do
      expect(@order.avalara_transaction.return_authorization.avalara_eligible).to eq(true)
    end
  end
  describe "#avalara_lookup" do
    it "should return lookup_avatax" do
      expect(@order.avalara_transaction.return_authorization.avalara_lookup).to eq(:lookup_avatax)
    end
    it "creates new avalara_transaction" do
      expect{@order.avalara_transaction.return_authorization.avalara_lookup}.to change{Spree::AvalaraTransaction.count}.by(1)
    end
  end
  describe "#avalara_capture" do
    it "should response with Spree::Adjustment object" do
      expect(@order.avalara_transaction.return_authorization.avalara_capture).to be_kind_of(Spree::Adjustment)
    end
    it "creates new avalara_transaction" do
      expect{@order.avalara_transaction.return_authorization.avalara_capture}.to change{Spree::AvalaraTransaction.count}.by(1)
    end
  end
  describe "#avalara_capture_finalize" do
    it "should response with Spree::Adjustment object" do
      expect(@order.avalara_transaction.return_authorization.avalara_capture_finalize).to be_kind_of(Spree::Adjustment)
    end
    it "creates new avalara_transaction" do
      expect{@order.avalara_transaction.return_authorization.avalara_capture_finalize}.to change{Spree::AvalaraTransaction.count}.by(1)
    end
  end

  describe "#authorized" do
    it "returns inital state of authorized" do
      expect(@return_authorization.state).to eq("authorized")
    end
  end

  context "received" do
    before do
      @return_authorization.inventory_units << @inventory_unit
      @return_authorization.state = "authorized"
      allow(@order).to receive(:update!)
    end
    it "should update order state" do
      @return_authorization.receive!
      expect(@return_authorization.state).to eq("received")
    end
    it "should receive avalara_capture_finalize" do
      @return_authorization.add_variant(@variant.id, 1)
      expect(@return_authorization.receive!).to receive(:avalara_capture_finalize)
    end

    it "should mark all inventory units are returned" do
      expect(@inventory_unit).to receive(:return!)
      @return_authorization.receive!
    end

    it "should update order state" do
      expect(@order).to receive :avalara_capture_finalize
      @return_authorization.receive!
    end

  end
end