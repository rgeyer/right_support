require "spec_helper"

describe RightSupport::Net::S3Helper do

  def digest
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, passphrase, @valid_params[:data])
  end

  def ciphertext
    "\203\346\271\273\323\377r\246\002\204\231\374h\327!\323"
  end

  def passphrase
    "#{@valid_params[:key]}:key"
  end

  before(:all) do
    @valid_params = { :key => "foo", :data => "bar" }

    @bucket = flexmock("s3_bucket")
    @object = flexmock("s3_object")

    @bucket.should_receive(:key).and_return(@object)
    @bucket.should_receive(:put).with(String, String, Hash).and_return(true)
    @object.should_receive(:meta_headers).and_return({"digest" => digest})
    @object.should_receive(:data).and_return(ciphertext)

    flexmock(RightSupport::Net::S3Helper).should_receive(:s3_enabled?).and_return(:true)
    flexmock(RightSupport::Net::S3Helper).should_receive(:bucket).and_return(@bucket)
    flexmock(RightSupport::Net::S3Helper).should_receive(:master_secret).and_return('key')

    s3 = flexmock("s3")
    s3.should_receive(:new).with(String, String).and_return(true)
    s3_config = {'creds' => {'aws_access_key_id' => '@@AWS_ACCESS_KEY_ID@@', 'aws_secret_access_key' => '@@AWS_SECRET_ACCESS_KEY@@'}, 'bucket_name' => '@@BUCKET_NAME@@', 'master_secret' => '@@MASTER_SECRET@@'}
    encrypt = flexmock("encrypt")
    encrypt.should_receive(:encrypt).with(String, String, Hash).and_return(ciphertext)
    encrypt.should_receive(:encrypt).with(Hash).and_return(ciphertext)
    encrypt.should_receive(:decrypt).with(Hash).and_return(@valid_params[:data])
    RightSupport::Net::S3Helper.init(s3_config, s3, encrypt)
  end

  context :get do
    context "with valid params" do
      it 'returns plaintext' do
        RightSupport::Net::S3Helper.get(@valid_params[:key]).should be_eql(@valid_params[:data])
      end
    end
  end

  context :post do
    context "with valid params" do
      it 'encrypts and saves data' do
        @bucket.should_receive(:put).with(@valid_params[:key], ciphertext, {"digest" => digest}).and_return(true)
        RightSupport::Net::S3Helper.post(@valid_params[:key], @valid_params[:data]).should be_true
      end
    end
  end

  context :health_check do

    context 'with invalid configuration' do
      before :each do
        flexmock(RightSupport::Net::S3Helper).should_receive(:config).and_return({'creds' => {'aws_access_key_id' => '@@AWS_ACCESS_KEY_ID@@', 'aws_secret_access_key' => '@@AWS_SECRET_ACCESS_KEY@@'}, 'bucket_name' => '@@BUCKET_NAME@@', 'master_secret' => '@@MASTER_SECRET@@'})
      end

      it 'return error' do
        RightSupport::Net::S3Helper.health_check.class.should == String
      end
    end

    context 'with valid configuration but invalid s3 connection credentials' do
      before :each do
        flexmock(RightSupport::Net::S3Helper).should_receive(:config).and_return({'creds' => {'aws_access_key_id' => 'AWS_ACCESS_KEY_ID', 'aws_secret_access_key' => 'AWS_SECRET_ACCESS_KEY'}, 'bucket_name' => 'BUCKET_NAME', 'master_secret' => 'MASTER_SECRET'})
      end

      it 'returns error ' do
        RightSupport::Net::S3Helper.health_check.class.should == String
      end
    end

    context 'with valid configuration and s3 connection' do
      before :each do
        flexmock(RightSupport::Net::S3Helper).should_receive(:config).and_return({'creds' => {'aws_access_key_id' => 'dsfgdsfgdsfgdsfg', 'aws_secret_access_key' => 'sdghdhsdg'}, 'bucket_name' => 'dshdshdfgh', 'master_secret' => 'dshdshg'})
        flexmock(RightSupport::Net::S3Helper).should_receive(:post).with('ping', 'heath check').and_return(true)
        flexmock(RightSupport::Net::S3Helper).should_receive(:get).with('ping').and_return('heath check')
      end

      it 'returns ok' do
        RightSupport::Net::S3Helper.health_check.should == true
      end
    end
  end

end
