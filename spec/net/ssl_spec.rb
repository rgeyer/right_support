require 'spec_helper'

describe RightSupport::Net::SSL::OpenSSLPatch do
  subject { RightSupport::Net::SSL::OpenSSLPatch }
  it 'is enabled by default' do
    subject.enabled?.should be_true
  end

  it 'can be enabled' do
    subject.enable!
    OpenSSL::SSL.should respond_to(:verify_certificate_identity_without_hack)
    subject.enabled?.should be_true
  end

  it 'can be disabled' do
    subject.disable!
    subject.enabled?.should be_false
  end
end

describe RightSupport::Net::SSL do
  context :with_expected_hostname do
    it 'works' do
      cert = flexmock('SSL certificate')

      flexmock(OpenSSL::SSL).
          should_receive(:verify_certificate_identity_without_hack).
          with(cert, 'reposeX.rightscale.com').and_return(true)
      RightSupport::Net::SSL.with_expected_hostname('reposeX.rightscale.com') do
        OpenSSL::SSL.verify_certificate_identity(cert, '1.2.3.4').should be_true
      end
    end

    context 'with disabled monkey-patch' do
      before(:each) do
        flexmock(RightSupport::Net::SSL::OpenSSLPatch).should_receive(:enabled?).and_return(false)
      end
      it 'does not work' do
        cert = flexmock('SSL certificate')
        flexmock(OpenSSL::SSL).
            should_receive(:verify_certificate_identity_without_hack).
            with(cert, '1.2.3.4').and_return(false)

        RightSupport::Net::SSL.with_expected_hostname('reposeX.rightscale.com') do
          OpenSSL::SSL.verify_certificate_identity(cert, '1.2.3.4').should be_false
        end
      end
    end
  end
end
