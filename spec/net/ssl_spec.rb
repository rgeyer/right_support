require 'spec_helper'

describe RightSupport::Net::SSL do
  PATCH = RightSupport::Net::SSL::OpenSSLPatch

  context :with_expected_hostname do
    before(:all) do
      PATCH.enable!
    end

    it 'works' do
      OpenSSL::SSL.should respond_to(:verify_certificate_identity_without_hack)
      PATCH.enabled?.should be_true

      cert = flexmock('SSL certificate')

      flexmock(OpenSSL::SSL).
          should_receive(:verify_certificate_identity_without_hack).
          with(cert, 'reposeX.rightscale.com').and_return(true)
      RightSupport::Net::SSL.with_expected_hostname('reposeX.rightscale.com') do
        OpenSSL::SSL.verify_certificate_identity(cert, '1.2.3.4').should be_true
      end
    end

    context 'with disabled monkey-patch' do
      before(:all) do
        PATCH.disable!
      end
      it 'does not work' do
        PATCH.enabled?.should be_false
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
