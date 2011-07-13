# -*- coding: utf-8 -*-

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "GitFileService::Server" do

  before(:each) do
    @base_dir = File.expand_path("~/tmp/test_git_repo")
    @key = "08109901000_1"
    @path = File.expand_path(@key, @base_dir)
    @server = GitFileService::Server.new(@base_dir)
    @user_name = "猪狩完治"
    @email = "igari@local.co.jp"
  end

  after(:each) do
    if File.exist?(@base_dir)
      system("chmod -R +rw #{@base_dir}")
      system("rm -r #{@base_dir}")
    end
  end  

  it "should get device" do
    @server.get_device(@key).class.should == GitFileService::GitDevice
  end

  it "should auto create repository" do
    @server.get_device(@key)
    File.exist?(@path).should be_true
    File.exist?(File.expand_path(".git", @path)).should be_true
  end

  it "should call device method" do
    @server.save(@key, "hello.txt", "this is new file\n",
                 @user_name, @email).should be_true

    @server.exist?(@key, "hello.txt").should be_true
    @server.history(@key, "hello.txt").class.should == Array
    @server.read(@key, "hello.txt").should == "this is new file\n"

    @server.rename(@key, "hello.txt", "new_hello.txt",
                   @user_name, @email).should be_true

    @server.delete(@key, "new_hello.txt",
                   @user_name, @email).should be_true

    File.exist?(File.expand_path("hello.txt", @path)).should be_false
  end

end
