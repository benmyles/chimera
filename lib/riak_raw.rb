# gem "typhoeus", "= 0.1.18"
# gem "uuidtools", "= 2.1.1"
# gem "brianmario-yajl-ruby", "= 0.6.3"
# require "typhoeus"
# require "uuidtools"
# require "uri"
# require "yajl"

# A Ruby interface for the Riak (http://riak.basho.com/) key-value store.
# 
#    Example Usage:
#    
#    > client = RiakRaw::Client.new('127.0.0.1', 8098, 'raw')
#    > client.delete('raw_example', 'doctestkey')
#    > obj = client.store('raw_example', 'doctestkey', {'foo':2})
#    > client.fetch('raw_example', 'doctestkey')
module RiakRaw
  VERSION = '0.0.1'
  
  class Client
    attr_accessor :host, :port, :prefix, :client_id
        
    def initialize(host="127.0.0.1", port=8098, prefix='riak', client_id=SecureRandom.base64)
      @host = host
      @port = port
      @prefix = prefix
      @client_id = client_id
    end
    
    def bucket(bucket_name,keys=false)
      #request(:get, build_path(bucket_name))
      response = request(:get, 
        build_path(bucket_name),
        nil, nil,
        {"returnbody" => "true", "keys" => keys})
      if response.code == 200
        if json = response.body
          return Yajl::Parser.parse(json)
        end
      end; nil
    end
    
    def store(bucket_name, key, content, vclock=nil, links=[], content_type='application/json', w=2, dw=2, r=2)
      headers = { 'Content-Type' => content_type,
                  'X-Riak-ClientId' => self.client_id }
      if vclock
        headers['X-Riak-Vclock'] = vclock
      end

      response = request(:put, 
        build_path(bucket_name,key),
        content, headers,
        {"returnbody" => "false", "w" => w, "dw" => dw})
      
      # returnbody=true could cause issues. instead we'll do a
      # separate fetch. see: https://issues.basho.com/show_bug.cgi?id=52
      if response.code == 204
        response = fetch(bucket_name, key, r)
      end
      
      response
    end
    
    def fetch(bucket_name, key, r=2)
      response = request(:get,
        build_path(bucket_name, key),
        nil, {}, {"r" => r})
    end
    
    # there could be concurrency issues if we don't force a short sleep
    # after delete. see: https://issues.basho.com/show_bug.cgi?id=52
    def delete(bucket_name, key, dw=2)
      response = request(:delete,
        build_path(bucket_name, key),
        nil, {}, {"dw" => dw})
    end
    
    private
    
    def build_path(bucket_name, key='')
      "http://#{self.host}:#{self.port}/#{self.prefix}/#{URI.escape(bucket_name)}/#{URI.escape(key)}"
    end
    
    def request(method, uri, body="", headers={}, params={})
      hydra = Typhoeus::Hydra.new
      case method
      when :get then
        req = Typhoeus::Request.new(uri, :method => :get, :body => body, :headers => headers, :params => params)
      when :post then
        req = Typhoeus::Request.new(uri, :method => :post, :body => body, :headers => headers, :params => params)
      when :put then
        req = Typhoeus::Request.new(uri, :method => :put, :body => body, :headers => headers, :params => params)
      when :delete then
        req = Typhoeus::Request.new(uri, :method => :delete, :body => body, :headers => headers, :params => params)
      end
      hydra.queue(req); hydra.run
      req.handled_response
    end
  end # Client
end