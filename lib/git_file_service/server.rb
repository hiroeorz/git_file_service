require "git_file_service/git_device"

module GitFileService
  class GitFileService
    def initialize(uri, pid_file)
      @uri = uri
      @pid_file = pid_file
    end

    def start
      if @debug
        run
      else
	daemon
	begin
	  open(@pid_file, "w") do |f|
	    f.puts(Process.pid)
	    f.truncate(f.tell)
	  end

          File.open(@last_sign_file, "w") do |f|
            f.truncate(f.tell)
          end
          
	  run
	rescue
          Syslog.crit("exit on critical error: %s", $!)
          exit(1)
	end
      end
    end

    private

    def daemon
      exit if fork
      exit if fork
      Process.setsid
      STDIN.close
      STDOUT.reopen("/dev/null", "w")
      STDERR.reopen("/dev/null", "w")
    end

    def run
      @drb = DRb.start_service(@uri)
    end
  end
end
