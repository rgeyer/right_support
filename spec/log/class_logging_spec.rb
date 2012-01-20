require 'spec_helper'

class InnocentVictim
  include RightSupport::Log::ClassLogging
end

describe RightSupport::Log::ClassLogging do
  context 'when mixed into a base class' do
    before(:each) do
      @victim = InnocentVictim.new
    end

    it 'provides a class-level accessor' do
      @victim.class.should respond_to(:logger)
      @victim.class.should respond_to(:logger=)
    end

    it 'provides an instance-level accessor' do
      @victim.should respond_to(:logger)
    end

    context :logger do
      context 'when no logger is provided' do
        before(:each) do
          @victim.class.logger = nil
        end

        it 'does nothing' do
          @victim.class.logger.info('lalalala').should be_true
          @victim.logger.info('lalalala').should be_true
        end
      end

      context 'when a logger is provided' do
        before(:each) do
          @logger = flexmock(Logger)
          @victim.class.logger = @logger
        end

        it 'performs logging' do
          @logger.should_receive(:info).and_return(true).twice
          @victim.class.logger.info('lalalala').should be_true
          @victim.logger.info('lalalala').should be_true
        end
      end
    end
  end
end