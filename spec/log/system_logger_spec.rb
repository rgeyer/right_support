require 'spec_helper'

# NOTE: this spec does not get defined or executed unless SystemLogger
# is defined, which only happens if Ruby standard-library 'syslog' module is
# available at runtime. Thus, the spec does not run on Windows.
#
# The selective execution is accomplished with a trailing 'if' for this
# outermost describe block. Crude but effective. You have been warned!
describe 'RightSupport::Log::SystemLogger' do
  subject { RightSupport::Log::SystemLogger }

  # Duplicate constants for easier reading
  SEVERITY_MAP = RightSupport::Log::SystemLogger::SEVERITY_MAP
  FACILITY_MAP = RightSupport::Log::SystemLogger::FACILITY_MAP

  before(:each) do
    @mock_syslog = flexmock(Syslog)
    #indicates we sent a bogus severity to syslog!
    @mock_syslog.should_receive(SEVERITY_MAP[Logger::UNKNOWN]).never
    flexmock(Syslog).should_receive(:open).and_return(@mock_syslog).by_default
  end

  after(:each) do
    subject.instance_eval { class_variable_set(:@@syslog, nil) }
  end

  context :initialize do
    context 'with :facility option' do
      FACILITY_MAP.each_pair do |name, const|
        it "should handle #{name}" do
          @mock_syslog.should_receive(:open).with('unit tests', nil, const)
          subject.new('unit tests', :facility=>name)
        end
      end
    end
  end

  context :add do
    context 'severity levels' do
      levels = { :debug=>:debug,
                 :info=>:info, :warn=>:notice,
                 :error=>:warning, :fatal=>:err }

      levels.each_pair do |logger_method, syslog_method|
        it "translates Logger##{logger_method} to Syslog##{syslog_method}" do
          @logger = subject.new('spec')
          @mock_syslog.should_receive(syslog_method).with('moo bah oink')
          @logger.__send__(logger_method, 'moo bah oink')
        end
      end
    end

    it 'escapes % characters to avoid confusing printf()' do
      @logger = subject.new('spec')
      flexmock(@logger).should_receive(:emit_syslog).with(Integer, 'All systems 100%% -- %%licious!')

      @logger.info('All systems 100% -- %licious!')
    end

    context 'given :split option' do
      it 'when true, splits multi-line messages' do
        @logger = subject.new('spec', :split=>true)
        flexmock(@logger).should_receive(:emit_syslog).times(5)

        @logger.info("This is a\nmulti line\r\nlog message\n\rwith all kinds\n\n\rof stuff")
      end

      it 'when false, passes through multi-line messages' do
        @logger = subject.new('spec', :split=>false)
        flexmock(@logger).should_receive(:emit_syslog).times(1)

        @logger.info("This is a\nmulti line\r\nlog message\n\rwith all kinds\n\n\rof stuff")
      end
    end

    context 'given :color option' do
      it 'when true, passes through ANSI color codes' do
        @logger = subject.new('spec', :color=>true)
        flexmock(@logger).should_receive(:emit_syslog).with(Integer, /[\e]/)

        @logger.info("This has \e[16;32mcolor\e[7;0m inside it!")
      end

      it 'when false, strips out ANSI color codes' do
        @logger = subject.new('spec', :color=>false)
        flexmock(@logger).should_receive(:emit_syslog).with(Integer, /[^\e]/)

        @logger.info("This has \e[16;32mcolor\e[7;0m inside it!")
      end
    end
  end
end if defined?(RightSupport::Log::SystemLogger)