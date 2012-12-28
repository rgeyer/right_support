# Copyright (c) 2009-2011 RightScale, Inc, All Rights Reserved Worldwide.
#
# THIS PROGRAM IS CONFIDENTIAL AND PROPRIETARY TO RIGHTSCALE
# AND CONSTITUTES A VALUABLE TRADE SECRET.  Any unauthorized use,
# reproduction, modification, or disclosure of this program is
# strictly prohibited.  Any use of this program by an authorized
# licensee is strictly subject to the terms and conditions,
# including confidentiality obligations, set forth in the applicable
# License Agreement between RightScale.com, Inc. and the licensee.

module RightSupport::Net
  # Class that provides S3 functionality.
  # As part of RightSupport S3Helper does not include Rightscale::S3 and Encryptor modules.
  # This modules must be included in application.
  #
  # @deprecated do not use; please use RightServices::Util::S3Storage instead!
  #
  # Example:
  #
  # require 'right_support'
  # require 'right_aws'
  # require 'encryptor'
  #
  # s3_config = YAML.load_file(File.expand_path("../../config/s3.yml",__FILE__))[ENV['RACK_ENV']]
  # RightSupport::Net::S3Helper.init(s3_config, Rightscale::S3, Encryptor)
  # s3_health = RightSupport::Net::S3Helper.health_check
  class S3Helper
    class BucketNotFound < Exception; end

    # Init() is the first method which must be called.
    # This is configuration and integration with S3 and Encryptor
    #
    # @param  [Hash]  config     config for current environment (from YAML config file)
    #                              creds:
    #                                aws_access_key_id: String
    #                                aws_secret_access_key: String
    #                              bucket_name: String
    #                              master_secret: String
    # @param  [Class] s3         Rightscale::S3 class is used to connect to S3
    # @param  [Class] encryptor  Class which will be used to encrypt data
    #                              encrypt() and decrypt() methods must be implemented
    #
    # @raise BucketNotFound if bucket name specified in config["bucket_name"] does not exist
    #
    # @return [true] always returns true
    def self.init(config, s3, encryptor, options = {})
      @config = config
      @s3class = s3
      @encryptor = encryptor
      @options = options

      # Reset any S3 objects we'd been caching, since config may have changed
      @s3 = @bucket = nil
      # Make sure our bucket exists -- better to do it now than on first access!
      self.bucket

      true
    end

    # Checks S3 credentials syntax in config parameter
    #
    # @return  [Boolean]  true if s3 creadentials are ok or false if not
    def self.s3_enabled?
      return @s3_enabled if @s3_enabled
      @s3_enabled ||= !config.empty? &&
        !config["creds"].empty?    &&
        !config["creds"]["aws_access_key_id"].nil? &&
        config["creds"]["aws_access_key_id"] != "@@AWS_ACCESS_KEY_ID@@"
    end
    # Returns @config parameter
    def self.config
      @config
    end
    # Create (if does not exist) and return S3 object
    def self.s3
      @s3 ||= @s3class.new config["creds"]["aws_access_key_id"], config["creds"]["aws_secret_access_key"], @options
    end
    # Create Bucket object using S3 object
    # @raise BucketNotFound if bucket name specified in config["bucket_name"] does not exist
    def self.bucket
      @bucket ||= s3.bucket(config["bucket_name"])
      raise BucketNotFound, "Bucket #{config["bucket_name"]} does not exist" if @bucket.nil?
      @bucket
    end
    # Returns Master secret from config
    def self.master_secret
      config["master_secret"]
    end
    # Downloads data from S3 Bucket
    #
    # @param   [String]  key   Name of the bucket key
    # @param   [Block]   blck  Ruby code wich will be done by Bucket object
    #
    # @return  [String]  S3 bucket's key content in plain/text format
    def self.get(key, &blck)
      return nil unless s3_enabled?

      object = bucket.key(key, true, &blck)
      return nil if object.nil?

      # don't decrypt/verify unencrypted values
      return object.data if object.meta_headers["digest"].nil?

      ciphertext = object.data
      passphrase = "#{key}:#{master_secret}"
      plaintext = @encryptor.decrypt(:key=>passphrase, :value=>ciphertext)
      digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, passphrase, plaintext)

      if digest == object.meta_headers["digest"]
        return plaintext
      else
        raise "digest for key:#{key} in s3 does not match calculated digest."
      end
    end
    # Upload data to S3 Bucket
    #
    # @param   [String]  key        Name of the bucket key
    # @param   [String]  plaintext  Data which should be saved in the Bucket
    # @param   [Block]   blck       Ruby code wich will be done by Bucket object
    #
    def self.post(key, plaintext, &blck)
      passphrase = "#{key}:#{master_secret}"
      plaintext = "-- no detail --" unless plaintext && plaintext.size > 0
      ciphertext = @encryptor.encrypt(:key=>passphrase, :value=>plaintext)
      digest = OpenSSL::HMAC.hexdigest(OpenSSL::Digest::SHA1.new, passphrase, plaintext)
      bucket.put(key, ciphertext, {"digest" => digest}, &blck)
    end
    # Checks if it is possible to connect to the S3 Bucket.
    #
    # @return [String or True]  If test was successful then return true
    #                           Else return error message
    def self.health_check
      config
      s3
      # test config file
      return 'S3 Config file: Credentials: Syntax error.' unless s3_enabled?
      ["bucket_name", "master_secret"].each do |conf|
        return "S3 Config file: #{conf.upcase}: Syntax error." if config[conf].nil? || config[conf] == '' || config[conf] == "@@#{conf.upcase}@@"
      end
      # test connection
      original_text = 'heath check'
      test_key  = 'ping'
      begin
        post(test_key, original_text)
      rescue Exception => e
        return e.message
      end
      begin
        result_text = get(test_key)
      rescue Exception => e
        return e.message
      end
      return 'Sended text and returned one are not equal. Possible master_secret problem' if result_text != original_text
      # retrurn true if there were not errors
      true
    end

  end

end
