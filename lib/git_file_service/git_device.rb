require "grit"
require "fileutils"

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

    def create(filename, data, message = nil)
      message = "create new file at #{Time.now.to_s}" if message.nil?

      in_repository(@base_dir, :check_path => filename) do
        File.open(filename, "wb") do |f|
          f.write(data)
        end
        
        new_blob = Grit::Blob.create(@repo, {:name => filename, :data => data})
        @repo.add(new_blob.name)
        @repo.commit_index(message)
        File.exist?(filename)
      end
    end

    def remove(filename, message = "remove file at #{Time.now.to_s}")
      in_repository(@base_dir, :check_path => filename) do
        @repo.remove(filename)
        @repo.commit_index(message)
        !File.exist?(filename)
      end
    end

    def rename(filename1, filename2, 
               message = "rename file at #{Time.now.to_s}")
      return false if filename1 == filename2

      in_repository(@base_dir, :check_path => [filename1, filename2]) do
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

    def update(filename, data, message = nil)
      message = "update file at #{Time.now.to_s}" if message.nil?

      in_repository(@base_dir, :check_path => filename) do
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
      in_repository(@base_dir, :check_path => filename) do
        @repo.tree.contents.collect{ |c| c.name }.include?(filename)
      end
    end

    def save(filename, data, message = nil)
      in_repository(@base_dir, :check_path => filename) do
        unless exist?(filename)
          return create(filename, data, message)
        end

        update(filename, data, message)
      end      
    end

    def list(dir = "/")
      in_repository(@base_dir, :check_path => dir) do
        @repo.tree.contents.collect{ |c|
          {
            "size" => c.size,
            "mime_type" => c.mime_type,
            "name" => c.name,
            "id" => c.id
          }
        }
      end      
    end

    def history(filename, opts = {:max_count => 5, :skip => 0}, 
                branch = "master")
      in_repository(@base_dir, :check_path => filename) do
        @repo.log(branch, filename, opts).collect { |commit|
          chash = commit.to_hash
          chash["created_at"] = commit.authored_date
          chash["updated_at"] = commit.committed_date
          chash
        }
      end      
    end

    def read(filename, commit_id = nil)
      in_repository(@base_dir, :check_path => filename) do
        if commit_id
          commit = @repo.commit(commit_id)
          blob = commit.tree / filename
        else
          blob = @repo.tree / filename
        end

        blob.data
      end
    end

    def info(filename, branch = "master")
      in_repository(@base_dir, :check_path => filename) do
        info = {}

        @repo.tree.contents.each do |c|
          nexit if c.name != filename
          info.merge!({
                        "size" => c.size,
                        "mime_type" => c.mime_type,
                        "name" => c.name,
                        "id" => c.id
                      })
        end
        
        history = history(filename, {:max_count => 1, :skip => 0}, branch).first

        ["message", "created_at", "updated_at"].each do |key|
          info[key] = history[key]
        end

        info
      end      
    end

    private

    def in_repository(dir, opts = {})
      if opts.has_key?(:check_path)
        check_secure_path(opts[:check_path])
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
