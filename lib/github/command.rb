require "readline"
require "abbrev"

if RUBY_PLATFORM =~ /mswin|mingw/
  begin
    require 'win32/open3'
  rescue LoadError
    warn "You must 'gem install win32-open3' to use the github command on Windows"
    exit 1
  end
else
  require 'open3'
end

module GitHub
  class Command
    def self.shell?
      @shell
    end

    def self.shell=(val)
      @shell = val
    end

    def initialize(block)
      (class << self;self end).send :define_method, :command, &block
    end

    def call(*args)
      arity = method(:command).arity
      args << nil while args.size < arity
      send :command, *args
    end

    def helper
      @helper ||= Helper.new
    end

    def options
      GitHub.options
    end

    def pgit(*command)
      puts git(*command)
    end

    def git(*command)
      sh ['git', command].flatten.join(' ')
    end

    def git_exec(*command)
      cmdstr = ['git', command].flatten.join(' ')
      GitHub.debug "exec: #{cmdstr}"
      Command.shell? ? system(cmdstr) : exec(cmdstr)
    end

    def sh(*command)
      Shell.new(*command).run
    end

    def die(message)
      puts "=> #{message}"
      exit!
    end

    class Shell < String
      attr_reader :error
      attr_reader :out

      def initialize(*command)
        @command = command
      end

      def run
        GitHub.debug "sh: #{command}"
        _, out, err = Open3.popen3(*@command)

        out = out.read.strip
        err = err.read.strip

        replace @error = err if err.any?
        replace @out = out if out.any?

        self
      end

      def command
        @command.join(' ')
      end

      def error?
        !!@error
      end

      def out?
        !!@out
      end
    end
  end

  class GitCommand < Command
    def initialize(name)
      @name = name
    end

    def command(*args)
      git_exec *[ @name, args ]
    end
  end

  class ShellCommand < Command
    def initialize
      Command.shell = true
    end

    def command(*args)
      cmds = GitHub.descriptions.keys.concat %w[help quit exit]
      cmd_abbrevs = cmds.map { |c| c.to_s }.abbrev
      Readline.completion_proc = proc do |str|
        str.empty? ? cmds : cmd_abbrevs[str]
      end

      loop do
        line = Readline::readline("github> ")
        cmd, *args = line.split(' ')
        case cmd
        when /^exit$/i, /^quit$/i
          break
        else
          GitHub.invoke(cmd, *args)
          Readline::HISTORY.push(line)
        end
      end
    end
  end
end
