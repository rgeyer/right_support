require 'spec_helper'

describe RightSupport::Log::NullLogger do
  before(:each) do
    @logger = RightSupport::Log::NullLogger.new
  end

  context 'log levels' do
    [:debug, :info, :warn, :error, :fatal].each do |method|
      it "responds to ##{method}" do
        block_called = false
        @logger.__send__(method, 'lalalala').should be_true
        @logger.__send__(method) { block_called = true ; 'lalalala' }.should be_true
        block_called.should be_true
      end
    end
  end

  context '<< method' do
    it 'responds like Logger' do
      (@logger << 'lalalala').should == 8
    end
  end

  context :close do
    it 'responds' do
      @logger.close.should be_nil
    end

    it 'is idempotent' do
      @logger.close.should be_nil
      @logger.close.should be_nil
      @logger.close.should be_nil
    end
  end
end