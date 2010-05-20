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

WOOHAH_VERSION = "0.0.0"

CHECKER_PAGE_URI = 'http://clang-analyzer.llvm.org/'

# settings to be tweaked by the user
CHECKER_INSTALL_LOCATION = '~/bin/'
CHECKER_SYMLINK_LOCATION = '~/bin/checker'
REMOVE_OLD_INSTALL = true

class GotYouAllInCheck
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
      @version_latest = "#{$1}"
    end

    @version_latest
  end

  def version_installed
    if @version_installed.nil?
      old_path = nil
      symlink_path = File.expand_path CHECKER_SYMLINK_LOCATION
      if File.exists? symlink_path and File.symlink? symlink_path
        old_path = File.readlink(symlink_path)
        @version_installed = File.basename old_path
      end
    end

    @version_installed
  end

  def print
    puts "version installed: #{(self.version_installed.nil? or self.version_installed.empty?) ? "NONE!" : self.version_installed}"
    puts "latest available: #{self.version_latest}"
  end
end



if $0 == __FILE__
  options = OpenStruct.new("clean" => REMOVE_OLD_INSTALL)
  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__, File.extname(__FILE__))} [options]"

    opts.separator ""
    opts.separator "Common options:"

    opts.on_tail("-c", "--clean", "Remove old copy on install of new") { options.clean = true }
    opts.on_tail("-d", "--dirty", "Keep old copy on install of new") { options.clean = false }

    opts.on_tail("-p", "--print", "Print installed and latest version strings") do
      g = GotYouAllInCheck.new
      g.print
      exit
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end

    # Another typical switch to print the version.
    opts.on_tail('-v', "--version", "Show version") do
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

  # dump help for now
  puts opts
  exit    
end
