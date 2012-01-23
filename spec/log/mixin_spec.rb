require 'spec_helper'

class InnocentVictim
  include RightSupport::Log::Mixin
end

describe RightSupport::Log::Mixin do
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
      context 'without a logger' do
        before(:each) do
          @victim.class.logger = nil
        end

        it 'does nothing' do
          @victim.class.logger.info('lalalala').should be_true
          @victim.logger.info('lalalala').should be_true
        end
      end

      context 'with class logger' do
        before(:each) do
          @logger = flexmock(Logger)
          @victim.class.logger = @logger
        end

        it 'uses class logger' do
          @logger.should_receive(:info).and_return(true).twice
          @victim.class.logger.info('lalalala').should be_true
          @victim.logger.info('lalalala').should be_true
        end

        context 'with instance logger' do
          before(:each) do
            @instance_logger = flexmock(Logger)
            @victim.logger = @instance_logger
          end

          it 'uses instance logger' do
            @instance_logger.should_receive(:info).and_return(true).once
            @logger.should_receive(:info).never
            @victim.logger.info('lalalala').should be_true
          end
        end
      end
    end
  end
end