require "grit"
require "fileutils"

module GitFileService
  class GitDevice
    attr_reader :base_dir, :repo

    def self.create_repositoty(path)
      FileUtils.makedirs(path)
      Grit::Repo.init(path)
      self.new(path)
    end

    def initialize(path)
      @repo = Grit::Repo.new(path)
      @base_dir = path
    end

    def create(filename, data, message = nil)
      message = "create new file at #{Time.now.to_s}"

      Dir.chdir(@base_dir) do
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
      Dir.chdir(@base_dir) do
        @repo.remove(filename)
        @repo.commit_index(message)
        !File.exist?(filename)
      end
    end

    def rename(filename1, filename2, 
               message = "rename file at #{Time.now.to_s}")
      return false if filename1 == filename2

      Dir.chdir(@base_dir) do
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

      Dir.chdir(@base_dir) do
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
      @repo.tree.contents.collect{ |c| c.name }.include?(filename)
    end

    def save(filename, data, message = nil)
      Dir.chdir(@base_dir) do
        unless exist?(filename)
          return create(filename, data, message)
        end

        update(filename, data, message)
      end      
    end

    def list(dir = "/")
      Dir.chdir(@base_dir) do
        @repo.tree.contents.collect{ |c|
          {
            :size => c.size,
            :mime_type => c.mime_type,
            :name => c.name,
            :id => c.id
          }
        }
      end      
    end

    def history(filename, opts = {:max_count => 5, :skip => 0}, 
                branch = "master")
      Dir.chdir(@base_dir) do
        @repo.log(branch, filename, opts).collect { |commit|
          chash = commit.to_hash
          chash["created_at"] = commit.authored_date
          chash["updated_at"] = commit.committed_date
          chash
        }
      end      
    end

    def read(filename, commit_id = nil)
      Dir.chdir(@base_dir) do
        if commit_id
          commit = @repo.commit(commit_id)
          blob = commit.tree / filename
        else
          blob = @repo.tree / filename
        end

        blob.data
      end
    end

  end
end
