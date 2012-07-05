Gem::Specification.new do |s|
  s.name = 'knife-table'
  s.version = '0.0.1'
  s.summary = 'Help chef set and serve the table'
  s.author = 'Chris Roberts'
  s.email = 'chrisroberts.code@gmail.com'
  s.homepage = 'http://github.com/heavywater/knife-table'
  s.description = "Chef's table"
  s.require_path = 'lib'
  s.files = Dir.glob('**/*')
  s.add_dependency 'knife-spork'
end
