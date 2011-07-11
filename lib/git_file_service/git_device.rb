# -*- coding: utf-8 -*-

require "grit"
require "fileutils"
require "kconv"

module GitFileService
  class GitDevice
    attr_reader :base_dir, :repo

    def self.create_repo(path)
      FileUtils.makedirs(path)
      Grit::Repo.init(path)
    end

    def initialize(path)
      if !File.exist?(File.expand_path(".git", path))
        self.class.create_repo(path)
      end

      @repo = Grit::Repo.new(path)
      @base_dir = path
    end

    def create(filename, data, user_name, email, message = nil)
      encoded_filename = (filename + "").force_encoding("utf-8")

      if message.nil? or message.empty?
        message = "create new file at #{Time.now.to_s}"
      end
 
      in_repository(@base_dir, user_name, email, 
                    :check_path => encoded_filename) do
        File.open(encoded_filename, "wb") do |f|
          f.write(data)
        end
        
        @repo.status.files.each do |name, file|
          @repo.add(file.path) if file.untracked
        end

        @repo.commit_all(message)

        File.exist?(encoded_filename)
      end
    end

    def remove(filename, user_name, email, 
               message = "remove file at #{Time.now.to_s}")
      in_repository(@base_dir, user_name, email, :check_path => filename) do
        @repo.remove(filename)
        @repo.commit_index(message)
        !File.exist?(filename)
      end
    end

    def rename(filename1, filename2, user_name, email,  
               message = "rename file at #{Time.now.to_s}")
      return false if filename1 == filename2

      in_repository(@base_dir, user_name, email, 
                    :check_path => [filename1, filename2]) do
        File.rename(filename1, filename2)
        blob = Grit::Blob.create(@repo, {:name => filename2, 
                                   :data => File.read(filename2)})
        @repo.add(blob.name)
        @repo.remove(filename1)
        @repo.commit_index(message)

        File.exist?(filename2) && !File.exist?(filename1) &&
          exist?(filename2) && !exist?(filename1)
      end      
    end

    def update(filename, data, user_name, email, message = nil)
      message = "update file at #{Time.now.to_s}" if message.nil?

      in_repository(@base_dir, user_name, email, :check_path => filename) do
        if !File.exist?(filename) or
            !@repo.tree.contents.collect{ |c| c.name }.include?(filename)
          raise ArgumentError.new("no such file on repository #{filename}")
        end

        File.open(filename, "wb") do |f|
          f.write(data)
        end

        blob = repo.tree / filename
        @repo.add(blob.name)
        @repo.commit_index(message)
        true
      end      
    end

    def exist?(filename)
      in_repository(@base_dir, nil, nil, :check_path => filename) do
        @repo.tree.contents.collect{ |c| c.name }.include?(filename)
      end
    end

    def save(filename, data, user_name, email, message = nil)
      in_repository(@base_dir, user_name, email, :check_path => filename) do
        if exist?(filename)
          return update(filename, data, user_name, email, message)
        end

        return create(filename, data, user_name, email, message)
      end      
    end

    def list(dir = "/")
      in_repository(@base_dir, nil, nil, :check_path => dir) do
        filelist = @repo.tree.contents.collect{ |b|
          b.name.force_encoding("utf-8")
          {
            "size" => b.size,
            "mime_type" => b.mime_type,
            "name" => b.name,
            "id" => b.id
          }.merge(info(b.name))
        }

        filelist.sort!{|a, b| b["updated_at"] <=> a["updated_at"]}
      end      
    end

    def history(filename, opts = {:max_count => 5, :skip => 0}, 
                branch = "master")

      in_repository(@base_dir, nil, nil, :check_path => filename) do
        @repo.log(branch, filename, opts).collect { |commit|
          chash = commit.to_hash
          chash["message"].force_encoding("utf-8")
          chash["author"]["email"].force_encoding("utf-8")
          chash["author"]["name"].force_encoding("utf-8")
          chash["committer"]["name"].force_encoding("utf-8")
          chash["committer"]["email"].force_encoding("utf-8")
          chash["created_at"] = commit.authored_date
          chash["updated_at"] = commit.committed_date
          chash
        }
      end      
    end

    def read(filename, commit_id = nil)
      filename.force_encoding("utf-8")

      in_repository(@base_dir, nil, nil, :check_path => filename) do
        if commit_id
          commit = @repo.commit(commit_id)
          blob = find_contents(commit.tree, filename)
        else
          blob = find_contents(@repo.tree, filename)
        end

        blob.data
      end
    end

    def info(filename, branch = "master")
      in_repository(@base_dir, nil, nil, :check_path => filename) do
        commit = find_contents(@repo.tree, filename)
        info = {
          "size" => commit.size,
          "mime_type" => commit.mime_type,
          "name" => commit.name,
          "id" => commit.id
        }

        history = history(filename, {:max_count => 1, :skip => 0}, branch).first
        history = {} if history.nil?
        ["message", "created_at", "updated_at"].each do |key|
          info[key] = history[key]
        end

        info
      end      
    end

    private

    def find_contents(tree, filename)
      tree.contents.find { |c|
        c.name.force_encoding("utf-8")
        c.name == filename
      }
    end

    def in_repository(dir, user_name, email, opts = {})
      if opts.has_key?(:check_path)
        check_secure_path(opts[:check_path])
      end

      if !user_name.nil? and !email.nil?
        @repo.config["user.name"] = user_name
        @repo.config["user.email"] = email
      end

      Dir.chdir(@base_dir) do
        yield
      end
    end

    def check_secure_path(paths)
      if paths.kind_of?(Array)
        array = paths
      else
        array = [paths]
      end

      array.each do |path|
        if path =~ /\.\./
          raise SecurityError.new("Invalid Pathname:#{path}")
        end
      end
    end
  end

  class SecurityError < StandardError
  end

end
