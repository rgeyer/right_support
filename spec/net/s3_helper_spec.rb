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

  before(:each) do
    @valid_params = { :key => "foo", :data => "bar" }

    # Mock right_aws config & objects with reasonable default behavior
    @s3_config = {'creds' =>
                      {'aws_access_key_id' => 'knock_knock',
                       'aws_secret_access_key' => 'open_sesame'},
                  'bucket_name' => 'my_own_personal_bucket',
                  'master_secret' => 'if i told you i would have to kill you'}
    @s3_class  = flexmock("s3")
    @s3_object = flexmock("s3_object")
    @s3_bucket = flexmock("s3_bucket")
    @s3_class.should_receive(:new).with(String, String, Hash).and_return(@s3_object)
    @s3_object.should_receive(:bucket).with('my_own_personal_bucket').and_return(@s3_bucket).by_default
    @s3_bucket.should_receive(:key).and_return(@s3_object).by_default
    @s3_bucket.should_receive(:put).with(String, String, Hash).and_return(true).by_default

    @s3_object.should_receive(:meta_headers).and_return({"digest" => digest})
    @s3_object.should_receive(:data).and_return(ciphertext)

    flexmock(RightSupport::Net::S3Helper).should_receive(:s3_enabled?).and_return(:true)
    flexmock(RightSupport::Net::S3Helper).should_receive(:master_secret).and_return('key')

    @encrypt = flexmock("encrypt")
    @encrypt.should_receive(:encrypt).with(String, String, Hash).and_return(ciphertext)
    @encrypt.should_receive(:encrypt).with(Hash).and_return(ciphertext)
    @encrypt.should_receive(:decrypt).with(Hash).and_return(@valid_params[:data])
  end

  context :init do
    context "when all params are valid" do
      it "succeeds" do
        RightSupport::Net::S3Helper.init(@s3_config, @s3_class, @encrypt).should be_true
      end
    end

    context "when bucket does not exist" do
      before(:each) do
        @bad_s3_config = @s3_config.clone
        @bad_s3_config['bucket_name'] = "supercallifragilisticexpialidocious"
        @s3_object.should_receive(:bucket).with("supercallifragilisticexpialidocious").and_return(nil)
      end

      it "raises BucketNotFound" do
        lambda {
          RightSupport::Net::S3Helper.init(@bad_s3_config, @s3_class, @encrypt)
        }.should raise_error(RightSupport::Net::S3Helper::BucketNotFound)
      end
    end
  end

  context :get do
    before(:each) do
      RightSupport::Net::S3Helper.init(@s3_config, @s3_class, @encrypt)
    end

    context "with valid params" do
      it 'returns plaintext' do
        RightSupport::Net::S3Helper.get(@valid_params[:key]).should be_eql(@valid_params[:data])
      end
    end
  end

  context :post do
    before(:each) do
      RightSupport::Net::S3Helper.init(@s3_config, @s3_class, @encrypt)
    end

    context "with valid params" do
      it 'encrypts and saves data' do
        @s3_bucket.should_receive(:put).with(@valid_params[:key], ciphertext, {"digest" => digest}).and_return(true)
        RightSupport::Net::S3Helper.post(@valid_params[:key], @valid_params[:data]).should be_true
      end
    end
  end

  context :health_check do
    before(:each) do
      RightSupport::Net::S3Helper.init(@s3_config, @s3_class, @encrypt)
    end

    context 'with invalid configuration' do
      before :each do
        flexmock(RightSupport::Net::S3Helper).should_receive(:config).and_return({'creds' => {'aws_access_key_id' => '@@AWS_ACCESS_KEY_ID@@', 'aws_secret_access_key' => '@@AWS_SECRET_ACCESS_KEY@@'}, 'bucket_name' => '@@s3_bucket_NAME@@', 'master_secret' => '@@MASTER_SECRET@@'})
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

  context 'test/development environment' do

    before :each do
      @key1 = 'aws_access_key_id'
      @key2 = 'aws_secret_access_key'
      @opt_with_no_subdomains = {:no_subdomains => true}
      @opt_without_subdoamins = {}
      @config = {}
      @config["creds"] = {}
      @config["creds"]["aws_access_key_id"] = @key1
      @config["creds"]["aws_secret_access_key"] = @key2
      @s3_class = flexmock('Rightscale::S3')
      flexmock(RightSupport::Net::S3Helper).should_receive(:bucket).and_return(true)
    end

    it 'works ok with :no_subdomains' do
      @s3_class.should_receive(:new).with(@key1, @key2, @opt_with_no_subdomains)
      RightSupport::Net::S3Helper.init(@config, @s3_class, @s3_class, :no_subdomains => true)
      RightSupport::Net::S3Helper.s3
    end

    it 'works ok without subdomains' do
      @s3_class.should_receive(:new).with(@key1, @key2, @opt_without_subdoamins)
      RightSupport::Net::S3Helper.init(@config, @s3_class, @s3_class)
      RightSupport::Net::S3Helper.s3
    end

  end

end
