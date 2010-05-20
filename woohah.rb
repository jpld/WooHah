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
CLEAN_OLD_INSTALLS = true



if $0 == __FILE__
  options = OpenStruct.new("clean" => CLEAN_OLD_INSTALLS)
  opts = OptionParser.new do |opts|
    opts.banner = "Usage: #{File.basename(__FILE__, File.extname(__FILE__))} [options]"

    opts.separator ""
    opts.separator "Common options:"

    opts.on_tail("-c", "--clean", "Remove old copy on install of new") { options.clean = true }
    opts.on_tail("-d", "--dirty", "Keep old copy on install of new") { options.clean = false }

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
