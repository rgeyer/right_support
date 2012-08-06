module RightSupport::Net
  if require_succeeds?('right_http_connection')
    #nothing, nothing at all! just need to make sure
    #that RightHttpConnection gets loaded before
    #rest-client, so the Net::HTTP monkey patches
    #take effect.
  end

  if require_succeeds?('restclient')
    HAS_REST_CLIENT = true
  end

  # Raised to indicate that no suitable provider of REST/HTTP services was found. Since RightSupport's
  # REST support is merely a wrapper around other libraries, it cannot work in isolation. See the REST
  # module for more information about supported providers.
  class NoProvider < Exception; end
  
  #
  # A wrapper for the rest-client gem that provides timeouts that make it harder to misuse RestClient.
  #
  # Even though this code relies on RestClient, the right_support gem does not depend on the rest-client
  # gem because not all users of right_support will want to make use of this interface. If one of HTTPClient
  # instance's method is called and RestClient is not available, an exception will be raised.
  #
  #
  # HTTPClient is a thin wrapper around the RestClient::Request class, with a few minor changes to its
  # interface, namely:
  #  * initializer accepts some default request options that can be overridden
  #    per-request
  #  * it has discrete methods for get/put/post/delete, instead of a single
  #    "request" method
  #  * it supports explicit :query and :payload options for query-string and
  #    request-body, and understands the Rails convention for encoding a
  #    nested Hash into request parameters.
  #
  # == Request Parameters
  # You can include a query-string with your request by passing the :query
  # option to any of the request methods. You can pass a Hash, which will
  # be translated to a URL-encoded query string using the Rails convention
  # for nesting. Or, you can pass a String which will be appended verbatim
  # to the URL. (In this case, don't forget to CGI.escape your string!)
  #
  # To include a form with your request, pass the :payload option to any
  # request method. You can pass a Hash, which will be translated to an
  # x-www-form-urlencoded request body using the Rails convention for
  # nesting. Or, you can pass a String which will be appended verbatim
  # to the URL. You can even use a binary String combined with a
  # suitable request-content-type header to pass binary data in the
  # payload. (In this case, be very careful about String encoding under
  # Ruby 1.9!)
  #
  # == Usage Examples
  #
  #   # Create an instance ot HTTPClient with some default request options
  #   @client = HTTPClient.new()
  #
  #   # Simple GET
  #   xml = @client.get 'http://example.com/resource'
  #
  #   # And, with timeout of 5 seconds...
  #   jpg = @client.get 'http://example.com/resource',
  #     {:accept => 'image/jpg', :timeout => 5}
  #
  #   # Doing some client authentication and SSL.
  #   @client.get 'https://user:password@example.com/private/resource'
  #   
  #   # The :query option will be encoded as a URL query-string using Rails
  #   # nesting convention (e.g. "a[b]=c" for this case).
  #   @client.get 'http://example.com', :query=>{:a=>{:b=>'c'}}
  #
  #   # The :payload option specifies the request body. You can specify a raw
  #   # payload:
  #   @client.post 'http://example.com/resource', :payload=>'hi hi hi lol lol'
  #
  #   # Or, you can specify a Hash payload which will be translated to a
  #   # x-www-form-urlencoded request body using the Rails nesting convention.
  #   # (e.g. "a[b]=c" for this case)
  #   @client.post 'http://example.com/resource', :payload=>{:d=>{:e=>'f'}}
  #
  #   # You can specify query and/or payload for any HTTP verb, even if it
  #   # defies convention  (be careful!)
  #   @client.post 'http://example.com/resource',
  #     :query   => {:query_string_param=>'hi'}
  #     :payload => {:form_param=>'hi'}, :timeout => 10
  #
  #   # POST and PUT with raw payloads
  #   @client.post 'http://example.com/resource',
  #     {:payload => 'the post body',
  #      :headers => {:content_type => 'text/plain'}}
  #   @client.post 'http://example.com/resource.xml',
  #     {:payload => xml_doc}
  #   @client.put 'http://example.com/resource.pdf',
  #     {:payload => File.read('my.pdf'),
  #      :headers => {:content_type => 'application/pdf'}}
  #
  #   # DELETE
  #   @client.delete 'http://example.com/resource'
  #
  #   # retrieve the response http code and headers
  #   res = @client.get 'http://example.com/some.jpg'
  #   res.code                    # => 200
  #   res.headers[:content_type]  # => 'image/jpg'
  class HTTPClient
    # The default options for every request; can be overridden by options
    # passed to #initialize or to the individual request methods (#get,
    # #post, and so forth).
    DEFAULT_OPTIONS = {
      :timeout      => 5,
      :open_timeout => 2,
      :headers      => {}
    }

    def initialize(defaults = {})
      @defaults = DEFAULT_OPTIONS.merge(defaults)
    end

    def get(*args)      
      request(:get, *args)
    end

    def post(*args)
      request(:post, *args)
    end

    def put(*args)
      request(:put, *args)
    end

    def delete(*args)
      request(:delete, *args)
    end

  # A very thin wrapper around RestClient::Request.execute.
  #
  # === Parameters
  # type(Symbol):: an HTTP verb, e.g. :get, :post, :put or :delete
  # url(String):: the URL to request, including any query-string parameters
  #
  # === Options
  # This method can accept any of the options that RestClient::Request can accept, since
  # all options are proxied through after merging in defaults, etc. Interesting options:
  # * :query - hash containing a query string (GET parameters) as a Hash or String
  # * :payload - hash containing the request body (POST or PUT parameters) as a Hash or String
  # * :headers - hash containing additional HTTP request headers
  # * :cookies - will replace possible cookies in the :headers
  # * :user and :password - for basic auth, will be replaced by a user/password available in the url
  # * :raw_response - return a low-level RawResponse instead of a Response
  # * :verify_ssl - enable ssl verification, possible values are constants from OpenSSL::SSL
  #     * OpenSSL::SSL::VERIFY_NONE (default)
  #     * OpenSSL::SSL::VERIFY_CLIENT_ONCE
  #     * OpenSSL::SSL::VERIFY_PEER
  #     * OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
  # * :timeout and :open_timeout - specify overall request timeout + socket connect timeout
  # * :ssl_client_cert, :ssl_client_key, :ssl_ca_file
  #
  # === Block
  # If the request succeeds, this method will yield the response body to its block.
  #
    def request(type, url, options={}, &block)
      options = @defaults.merge(options)

      # Handle query-string option which is implemented by us, not by rest-client.
      # (rest-client version of this, :headers={:params=>...}) but it
      # is broken in many ways and not suitable for use!)
      if query = options.delete(:query)
        url = process_query_string(url, query)
      end

      options.merge!(:method => type, :url => url)

      request_internal(options, &block)
    end

    private

    # Process a query-string option and append it to the URL as a properly
    # encoded query string. The input must be either a String or Hash and the
    # Hash may recursively contain String, Hash, and Array values.
    #
    # === Parameters
    # url(String):: the URL to request, including any query-string parameters
    # query(Hash|String):: the URL params, that will be added to URL, Hash or String
    #
    # === Return
    # (String) url concatenated with parameters
    def process_query_string(url='', query={})
      url_params = ''

      if query.kind_of?(String)
        url_params = query.gsub(/^\?/, '')
      elsif query.kind_of?(Hash)
        if require_succeeds?('addressable/uri')
          uri = Addressable::URI.new
          uri.query_values = query
          url_params = uri.query
        else
          url_params = hash_to_query_string(query)
        end
      else
        raise ArgumentError.new("Parameter query should be String or Hash")
      end
      unless (url+url_params)[/\?/]
        url_params = '?' + url_params unless url_params.empty?
      end

      url + url_params
    end

    # Convert a hash into a string suitable for use as a URL query string
    #
    # === Examples
    # { :name => 'David', :nationality => 'Danish' }.to_query # => "name=David&nationality=Danish"
    #
    # { :name => 'David', :nationality => 'Danish' }.to_query('user') # => "user%5Bname%5D=David&user%5Bnationality%5D=Danish"
    #
    # === Parameters
    # hash(Hash):: Hash to be converted
    # namespace(String|nil):: Optional namespace to enclose param names
    #
    # === Return
    # (String):: Converted hash
    def hash_to_query_string(hash, namespace = nil)
      hash.collect do |key, value|
        key = namespace ? "#{namespace}[#{key}]" : key
        if value.kind_of?(Hash)
          hash_to_query_string(value, key)
        elsif value.kind_of?(Array)
          array_to_query_string(value, key)
        else
          "#{CGI.escape(key.to_s)}=#{CGI.escape(value.to_s)}"
        end
      end.sort.join('&')
    end

    # Convert an array into a string suitable for use as a URL query string
    #
    # === Examples
    # ['Rails', 'coding'].to_query('hobbies') # => "hobbies%5B%5D=Rails&hobbies%5B%5D=coding"
    #
    # === Parameters
    # array(Array):: Array to be converted
    # key(String):: Param name
    #
    # === Return
    # (String):: Converted array
    def array_to_query_string(array, key)
      prefix = "#{key}[]"
      array.collect do |value|
        if value.kind_of?(Hash)
          hash_to_query_string(value, prefix)
        elsif value.kind_of?(Array)
          array_to_query_string(value, prefix)
        else
          "#{CGI.escape(prefix)}=#{CGI.escape(value.to_s)}"
        end
      end.join('&')
    end

    # Wrapper around RestClient::Request.execute -- see class documentation for details.
    def request_internal(options, &block)
      if HAS_REST_CLIENT
        RestClient::Request.execute(options, &block)
      else
        raise NoProvider, "Cannot find a suitable HTTP client library"
      end
    end
  end# HTTPClient
end
