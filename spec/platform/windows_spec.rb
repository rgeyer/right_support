require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helper'))

describe RightSupport::Platform do
  subject { RightSupport::Platform }

  context 'under Windows' do
    context :installer do
      context :install do
        specify { lambda { subject.installer.install([]) }.should raise_exception }
      end
    end
  end
end if RightSupport::Platform.windows?