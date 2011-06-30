# -*- coding: utf-8 -*-
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require "git_file_service"
require "pathname"

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
end

def create_files_to_repository(fs, range, message_index = 0)
  datas = {}
  user_name = "猪狩完治 #{message_index}号機"
  email = "igari_#{message_index}@local.jp"

  for i in range
    datas["file_#{i}.txt"] = "data #{i}\n#{message_index}"
  end
  
  datas.each do |filename, data|
    fs.save(filename, data, user_name, email, 
            "updated #{filename}: #{message_index}")
  end

  datas
end
