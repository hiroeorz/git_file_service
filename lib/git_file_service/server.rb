# -*- coding: utf-8 -*-
require "timeout"
require "git_file_service/git_device"

module GitFileService
  class Server

    def initialize(base_dir)
      raise ArgumentError.new if !base_dir.kind_of?(String) or base_dir.empty?
      @base_dir = base_dir
      @devices = {}
      @device_max_time = 120
    end

    # 説明:: GitFileService::ServerクラスのDRbサーバを起動します。
    #
    # return value:: GitDevice instance
    def start_drb_server(uri)
      Drb.start_service(uri, self)
      sleep
    end

    # 説明:: GitDeviceのインスタンスを返します。
    # 捕捉:: 異なるスレッドが同じデバイスを並行的に使用しないようにQueueを使っています。
    # return value:: GitDevice instance
    def get_device(key)
      queue = @devices[key]

      if queue.nil?
        queue = Queue.new
        queue.enq(GitDevice.new(device_dir(key)))
        @devices[key] = queue
      end

      queue.deq
    end

    # 説明:: キューにデバイスを戻します。
    #
    # return value:: void
    def set_device(key, device)
      queue = @devices[key]

      if queue.nil?
        queue = Queue.new
        queue.enq(GitDevice.new(device_dir(key)))
        @devices[key] = queue
      else
        queue.enq(GitDevice.new(device_dir(key)))
      end
    end

    # 説明:: 与えられたキーからデバイスのディレクトリパスを生成します。
    #
    # return value:: String
    def device_dir(key)
      File.expand_path(key, @base_dir)
    end
    
    # 説明:: GitDeviceへの呼び出しをmethod_missing内から行います。
    #
    # return value:: value from GitDevice instance
    def method_missing(method_name, *params)
      key = params.first
      new_params = params[1..-1]      
      device = get_device(key)

      begin
        timeout(@device_max_time) do
          if device.respond_to?(method_name)
            return device.send(method_name, *new_params)
          end
        end
      ensure
        set_device(key, device)
      end
    end
    
  end
end
