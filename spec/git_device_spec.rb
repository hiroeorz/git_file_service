# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "GitFileService::GitDevice" do

  before(:each) do
    @path = File.expand_path("~/tmp/test_git_repo")
    @fs = GitFileService::GitDevice.new(@path)
  end

  after(:each) do
    system("chmod -R +rw #{@path}")
    system("rm -r #{@path}")
  end

  it "should be create new file" do
    File.exist?(@path).should be_true
  end

  it "should get base directory" do
    @fs.base_dir.should == @path
  end

  it "should be create new file" do
    @fs.create("hello.txt", "this is new file\n").should be_true
    @fs.exist?("hello.txt").should be_true
    File.exist?(File.expand_path("hello.txt", @path)).should be_true
  end

  it "should remove file" do
    @fs.remove("hello.txt").should be_true
    @fs.exist?("hello.txt").should be_false
    File.exist?(File.expand_path("hello.txt", @path)).should be_false
  end

  it "shoud update file" do
    @fs.create("hello.txt", "this is new file\n").should be_true
    @fs.update("hello.txt", 
               "this is new file\nthis is updated line").should be_true
  end

  it "should save file" do
    path = File.expand_path("hello.txt", @path)
    data1 = "line 1\n"
    data2 = data1 + "line2\n"

    @fs.save("hello.txt", data1, "initial create hello.txt").should be_true
    @fs.exist?("hello.txt")
    File.exist?(path).should be_true
    File.open(path) { |f| f.read.should == data1}

    @fs.save("hello.txt", data2, "updated hello.txt").should be_true
    @fs.exist?("hello.txt")
    File.exist?(path).should be_true
    File.open(path) { |f| f.read.should == data2}
  end

  it "should get file list" do
    datas = create_files_to_repository(@fs, 1 .. 10)

    @fs.list.class.should == Array
    @fs.list.size.should == 10

    @fs.list.each do |gfile|
      filename = gfile["name"]
      data = datas[filename]
      gfile["size"].should == data.size
      gfile["mime_type"].should == "text/plain"
    end
    
  end

  it "should get history of file" do
    for i in 0 .. 10
      datas = create_files_to_repository(@fs, 1 .. 10, i)
    end

    @fs.history("file_1.txt").size.should == 5
    @fs.history("file_1.txt", :max_count => 10).size.should == 10    
    @fs.history("file_1.txt").each_with_index do |h, i|
      h["message"].should == "updated file_1.txt: #{10 - i}"
      h["created_at"].class.should == Time
      h["updated_at"].class.should == Time
      h.should be_has_key "id"
    end
  end

  it "should get data from history id" do
    filename = "hello.txt"
    data1 = "line1\n"
    data2 = data1 + "line2\n"
    data3 = data2 + "line3\n"

    @fs.save(filename, data1, "initial create hello.txt")
    @fs.save(filename, data2, "updated hello.txt")
    @fs.save(filename, data3, "updated hello.txt")

    history = @fs.history(filename)
    history.size.should == 3
    @fs.read(filename, history[0]["id"]).should == data3
    @fs.read(filename, history[1]["id"]).should == data2
    @fs.read(filename, history[2]["id"]).should == data1
  end

  it "should rename file" do
    filename1 = "before.txt"
    filename2 = "after.txt"
    data1 = "line1\n"

    @fs.save(filename1, data1, "initial create hello.txt")
    @fs.rename(filename1, filename2).should be_true
    @fs.exist?(filename1).should be_false
    @fs.exist?(filename2).should be_true
    @fs.read(filename2).should == data1
  end

  it "should get information of file" do
    filename1 = "hello.txt"
    data1 = "line1\n"

    @fs.save(filename1, data1)
    info = @fs.info(filename1)
    info["name"].should == filename1
    info["size"].should == data1.size
    info["created_at"].class.should == Time
    info["updated_at"].class.should == Time
    info["mime_type"].should == "text/plain"
    info["message"].should =~ /create new file at/
  end

  it "should raise GitFileService::SecurityError when path included .." do
    lambda { @fs.save("../hello.txt", "aaa") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.list("../other_dir") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.create("../hello.txt", "aaa") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.update("../hello.txt", "aaa") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.read("../hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.remove("../hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.rename("../yoso/hello.txt", "/hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.rename("/hello.txt", "../yoso/hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.exist?("../hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.history("../hello.txt") }.
      should raise_error(GitFileService::SecurityError)

    lambda { @fs.info("../hello.txt") }.
      should raise_error(GitFileService::SecurityError)
  end

end
