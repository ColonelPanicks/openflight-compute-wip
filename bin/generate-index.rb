#!/usr/bin/env ruby

require 'yaml'
require 'erb'

@desktops = YAML.load_file( ENV['DESKTOPFILE'] || './desktops.yaml' )
index = ENV['INDEXFILE'] || './index.html'
template = ERB.new(File.read('templates/html/index.html.erb'))

File.open(index, 'w') do |f|
  f.write template.result()
end
