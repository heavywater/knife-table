$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'knife-table/version'
Gem::Specification.new do |s|
  s.name = 'knife-table'
  s.version = KnifeTable::VERSION
  s.summary = 'Help chef set and serve the table'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/heavywater/knife-table'
  s.description = "Chef's table"
  s.require_path = 'lib'
  s.files = Dir.glob('**/*')
  s.add_dependency 'knife-spork', '>= 0.1.11'
  s.add_dependency 'hub', '>= 1.10.1'
end
