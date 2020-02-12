#!/usr/bin/env ruby

require 'yaml'
require 'erb'

@desktops = YAML.load_file('./desktops.yaml')
index = ERB.new(File.read('templates/html/index.html.erb'))

File.open('index.html', 'w') do |f|
  f.write index.result()
end
