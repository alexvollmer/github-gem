$:.unshift File.dirname(__FILE__)
require 'github/extensions'
require 'github/command'
require 'github/helper'
require 'rubygems'
require 'open-uri'
require 'json'
require 'yaml'

##
# Starting simple.
#
# $ github <command> <args>
#
#   GitHub.command <command> do |*args|
#     whatever
#   end
#
# We'll probably want to use the `choice` gem for concise, tasty DSL
# arg parsing action.
#

module GitHub
  extend self

  BasePath = File.expand_path(File.dirname(__FILE__) + '/..')

  def command(command, options = {}, &block)
    debug "Registered `#{command}`"
    descriptions[command] = @next_description if @next_description
    @next_description = nil
    flag_descriptions[command].update @next_flags if @next_flags
    @next_flags = nil
    commands[command.to_s] = Command.new(block)
    Array(options[:alias] || options[:aliases]).each do |command_alias|
      commands[command_alias.to_s] = commands[command.to_s]
    end
  end

  def desc(str)
    @next_description = str
  end

  def flags(hash)
    @next_flags ||= {}
    @next_flags.update hash
  end

  def helper(command, &block)
    debug "Helper'd `#{command}`"
    Helper.send :define_method, command, &block
  end

  def activate(args)
    @@original_args = args.clone
    @options = parse_options(args)
    @debug = @options[:debug]
    load 'helpers.rb'
    load 'commands.rb'
    invoke(args.shift, *args)
  end

  def invoke(command, *args)
    block = find_command(command)
    debug "Invoking `#{command}`"
    block.call(*args)
  end

  def find_command(name)
    name = name.to_s
    commands[name] || GitCommand.new(name) || commands["default"]
  end

  def commands
    @commands ||= {}
  end

  def descriptions
    @descriptions ||= {}
  end

  def flag_descriptions
    @flagdescs ||= Hash.new { |h, k| h[k] = {} }
  end

  def options
    @options
  end

  def original_args
    @@original_args ||= []
  end

  def parse_options(args)
    idx = 0
    args.clone.inject({}) do |memo, arg|
      case arg
      when /^--(.+?)=(.*)/
        args.delete_at(idx)
        memo.merge($1.to_sym => $2)
      when /^--(.+)/
        args.delete_at(idx)
        memo.merge($1.to_sym => true)
      when "--"
        args.delete_at(idx)
        return memo
      else
        idx += 1
        memo
      end
    end
  end

  def load(file)
    file[0] == ?/ ? path = file : path = BasePath + "/commands/#{file}"
    data = File.read(path)
    GitHub.module_eval data, path
  end

  def debug(*messages)
    puts *messages.map { |m| "== #{m}" } if debug?
  end

  def debug?
    !!@debug
  end
end

GitHub.command :shell, :aliases => [''] do
  if ['-h', 'help', '-help', '--help'].member?(GitHub.original_args.first)
    GitHub.commands['help'].command
  else
    GitHub::ShellCommand.new.command
  end
end

GitHub.command :default, :aliases => ['-h', 'help', '-help', '--help'] do |*args|
  help_for = args.empty? ? nil : args.first.to_sym
  if help_for and not GitHub.descriptions[help_for]
    puts "Unknown command: #{help_for}"
    return
  else
    puts "Usage: github command <space separated arguments>", ''
    puts "Available commands:", ''
  end

  longest = GitHub.descriptions.map { |d,| d.to_s.size }.max
  GitHub.descriptions.each do |command, desc|
    next if help_for and help_for != command
    cmdstr = "%-#{longest}s" % command
    puts "  #{cmdstr} => #{desc}"
    flongest = GitHub.flag_descriptions[command].map { |d,| "--#{d}".size }.max
    GitHub.flag_descriptions[command].each do |flag, fdesc|
      flagstr = "#{" " * longest}  %-#{flongest}s" % "--#{flag}"
      puts "  #{flagstr}: #{fdesc}"
    end
  end
  puts
end
