#!/usr/bin/env ruby
#
#  Created by jpld on 19 May 2010.
#  Copyright (c) 2010 __MyCompanyName__. All rights reserved.

require 'open3'
require 'ostruct'
require 'optparse'
require 'fileutils'
require 'rubygems'
require 'hpricot'
require 'open-uri'

WOOHAH_VERSION = "0.2.2"

CHECKER_PAGE_URI = 'http://clang-analyzer.llvm.org/'

XCODE_SPEC_FPATH = '/Developer/Library/Xcode/Plug-ins/Clang LLVM 1.0.xcplugin/Contents/Resources/Clang LLVM 1.0.xcspec'
XCODE_SPEC_MARKER = 'ExecPath = "$(CLANG)";'

REMOVE_OLD_INSTALL = true

# settings to be tweaked by the user
CHECKER_INSTALL_LOCATION = '~/bin/'
CHECKER_SYMLINK_LOCATION = '~/bin/checker'


# TAKEN FROM HOMEBREW <http://github.com/mxcl/homebrew/blob/master/Library/Homebrew/global.rb>
class ExecutionError <RuntimeError
  attr :exit_status
  attr :command

  def initialize cmd, args = [], es = nil
    @command = cmd
    super "Failure while executing: #{cmd} #{pretty(args)*' '}"
    @exit_status = es.exitstatus rescue 1
  end

  # def was_running_configure?
  #   @command == './configure'
  # end

  private

  def pretty args
    args.collect do |arg|
      if arg.to_s.include? ' '
        "'#{ arg.gsub "'", "\\'" }'"
      else
        arg
      end
    end
  end
end

# TAKEN FROM HOMEBREW <http://github.com/mxcl/homebrew/blob/master/Library/Homebrew/utils.rb>
module Homebrew
  def self.system cmd, *args
    # puts "#{cmd} #{args*' '}" if ARGV.verbose?
    fork do
      yield if block_given?
      args.collect!{|arg| arg.to_s}
      exec(cmd, *args) rescue nil
      exit! 1 # never gets here unless exec failed
    end
    Process.wait
    $?.success?
  end
end

# Kernel.system but with exceptions
def safe_system cmd, *args
  raise ExecutionError.new(cmd, args, $?) unless Homebrew.system(cmd, *args)
end

# prints no output
def quiet_system cmd, *args
  Homebrew.system(cmd, *args) do
    $stdout.close
    $stderr.close
  end
end

def curl *args
  safe_system 'curl', '-f#L', *args unless args.empty?
end



class GotYouAllInCheck
  attr_reader :version_latest_uri, :symlink_path, :old_path

  def version_latest
    if @version_latest.nil?
      begin
        doc = Hpricot(open(CHECKER_PAGE_URI))
      rescue
        puts "ERROR - unable to connect to remote host at #{CHECKER_PAGE_URI}"
        exit 1
      end

      elem = (doc/"a").detect { |e| /(checker\-.*)\.tar\.bz2/.match(e.inner_text) }
      unless elem
        puts "ERROR - did not find the checker download link on page #{CHECKER_PAGE_URI}"
        exit 1
      end
      @version_latest = $1

      # TODO - be smarter about assembling the URI
      if elem['href'].match(/^http/)
        @version_latest_uri = elem['href']
      else
        @version_latest_uri = CHECKER_PAGE_URI + elem['href']
      end
    end

    @version_latest
  end

  def version_installed
    if @version_installed.nil?
      old_path = nil
      @symlink_path = File.expand_path CHECKER_SYMLINK_LOCATION
      if File.exists? symlink_path and File.symlink? @symlink_path
        @old_path = File.readlink(@symlink_path)
        @version_installed = File.basename @old_path
      end
    end

    @version_installed
  end

  def update(clean)
    if (self.version_latest === self.version_installed)
      puts "latest version '#{self.version_latest}' already installed"
      exit
    end

    if self.version_installed.nil? or self.version_installed.empty?
      puts "installing '#{self.version_latest}'"
    else
      puts "updating from '#{self.version_installed}' to '#{self.version_latest}'"
    end

    # download archive
    # if we bring in rubycocoa use NSDownloadsDirectory
    FileUtils.cd '/tmp'

    archive_basename = File.basename self.version_latest_uri
    # NB - can't migrate to safe_system since the output is needed
    out = %x{ curl -s -I #{self.version_latest_uri} }
    if out.match(/filename=\"(.*)\"/)
      archive_basename = $1
    end

    puts "downloading '#{self.version_latest_uri}'"

    curl(self.version_latest_uri, '-o', archive_basename)
    # unarchive
    puts "unarchiving..."
    quiet_system('tar', '-jxvf', archive_basename)
    FileUtils.rm archive_basename

    unarchived_basename = File.basename(archive_basename, '.tar.bz2')

    if !File.exists? File.join('/tmp', unarchived_basename)
      puts "ERROR - cannot find unarchived analyzer directory"
      exit 1
    end

    # rid ourselves of .svn directories
    quiet_system('find', unarchived_basename, '-name', '.svn', '-print0', '|', 'xargs', '-0', 'rm', '-rf')

    install_path = File.expand_path(CHECKER_INSTALL_LOCATION)
    # TODO - check for write privs
    FileUtils.mkdir_p(install_path) unless File.exists?(install_path)

    # move into install location
    # TODO - check for write privs, check if file exists
    FileUtils.cp_r unarchived_basename, install_path
    FileUtils.rm_r unarchived_basename

    puts "installing"

    # symlink spinup
    symlink_path_dir = File.dirname self.symlink_path
    # TODO - check for write privs
    FileUtils.mkdir_p(symlink_path_dir) if !File.exists?(symlink_path_dir)

    # symlink
    # remove previous, force doesn't seem to work really
    FileUtils.rm symlink_path if File.exists? symlink_path
    megapath = File.join(install_path, unarchived_basename)
    FileUtils.ln_s(megapath, symlink_path, :force => true)

    # clean
    if clean and not self.old_path.nil? and File.basename(self.old_path) =~ /^checker\-(.*)$/
      puts "removing previously installed version at path #{self.old_path}"
      FileUtils.rm_r self.old_path
    end
  end

  def xyzzy
    unless File.exists?(XCODE_SPEC_FPATH)
      puts "ERROR: did not find Xcode spec file at path '#{XCODE_SPEC_FPATH}'"
      exit 1
    end

    local_build_path = File.join(File.expand_path(CHECKER_SYMLINK_LOCATION), "bin/clang")
    new_exec_path = "ExecPath = \"" + local_build_path  + "\";"
    unless File.exists?(local_build_path)
      puts "ERROR: no local build to point to"
      exit 1
    end

    text = File.read(XCODE_SPEC_FPATH)
    if text.include? new_exec_path
      puts "Xcode spec already pointing to local build for analysis"
      exit
    end

    unless text.include? XCODE_SPEC_MARKER
      puts "ERROR: did not find Xcode spec replacement marker"
      exit 1
    end
    File.open(XCODE_SPEC_FPATH, "w") {|file| file.puts text.sub(XCODE_SPEC_MARKER, new_exec_path) }
    puts "Xcode spec updated to use local build for analysis"
  end

  def print
    puts "version installed: #{(self.version_installed.nil? or self.version_installed.empty?) ? "NONE!" : self.version_installed}"
    puts "latest available: #{self.version_latest}"
  end
end



if $0 == __FILE__
  options = OpenStruct.new("clean" => REMOVE_OLD_INSTALL)
  opts = OptionParser.new do |opts|
    # TODO - this '[options...]' business isn't quite right
    opts.banner = "Usage: #{File.basename(__FILE__, File.extname(__FILE__))} [options...]"

    opts.separator ""
    opts.separator "Common options:"

    opts.on_tail("-p", "--print", "Print installed and latest version strings") do
      g = GotYouAllInCheck.new
      g.print
      exit
    end

    opts.on_tail("-u", "--update", "Update to the latest") { options.update = true }
    opts.on_tail("-d", "--dirty", "Keep old copy when updating") { options.clean = false }


    opts.on_tail("-s", "--setup-xcode", "Have Xcode to use local build for analysis") { options.xyzzy = true }

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

    # Another typical switch to print the version.
    opts.on_tail('-v', "--version", "Show script version") do
      puts WOOHAH_VERSION
      exit
    end
  end


  # unknown args throw an exception
  begin
    opts.parse! ARGV
  rescue OptionParser::ParseError => e
    puts e
    puts opts
    exit 1
  end

  if options.update
    g = GotYouAllInCheck.new
    g.update(options.clean)
  end
  if options.xyzzy
    g = GotYouAllInCheck.new
    g.xyzzy
  end
  unless options.update or options.xyzzy
    puts opts
    exit
  end
end
