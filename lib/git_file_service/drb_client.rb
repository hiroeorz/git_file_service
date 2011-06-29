# -*- coding: utf-8 -*-
require "timeout"
require "drb/drb"

module GitFileService
  class DRbClient

    def initialize(uri, key)
      unless key.kind_of? String
        raise ArgumentError.new("key must be String object:#{key}")
      end

      @key = key
      @client = DRbObject.new_with_uri(uri)
    end

    def method_missing(method_name, *params)
      new_params = [@key] + params
      @client.send(method_name, *new_params)
    end

  end
end
