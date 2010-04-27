require 'timeout'
require 'mongo'

module Rack
  
  class GridFSConnectionError < StandardError ; end
  
  class GridFS

    attr_reader :hostname, :port, :database, :prefix, :db
    
    def initialize(app, options = {})
      options = {
        :hostname => 'localhost', 
        :prefix   => 'gridfs',
        :port     => Mongo::Connection::DEFAULT_PORT,
        :accessor => 'id'
      }.merge(options)

      @app        = app
      @hostname   = options[:hostname]
      @port       = options[:port]
      @database   = options[:database]
      @prefix     = options[:prefix]
      @accessor   = options[:accessor]
      @db         = nil

      connect!
    end

    def call(env)
      request = Rack::Request.new(env)
      if request.path_info =~ /^\/#{prefix}\/(.+)$/
        gridfs_request($1)
      else
        @app.call(env)
      end
    end

    def gridfs_request(path)
      if @accessor == 'id'
			file = Mongo::Grid.new(db).get(BSON::ObjectID.from_string(path))
		elsif @accessor == 'path'
			file = Mongo::GridFileSystem.new(db).open(path, "r")
		end
		[200, {'Content-Type' => file.content_type}, [file.read]]
    rescue Mongo::GridFileNotFound, Mongo::GridError, BSON::InvalidObjectID
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end
    
    private
    
    def connect!
      Timeout::timeout(5) do
        @db = Mongo::Connection.new(hostname).db(database)
      end
    rescue Exception => e
      raise Rack::GridFSConnectionError, "Unable to connect to the MongoDB server (#{e.to_s})"
    end
    
  end
    
end
