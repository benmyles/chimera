require 'rubygems'
gem 'hoe', '>= 2.1.0'
require 'hoe'
require 'fileutils'
require './lib/chimera'

Hoe.plugin :newgem
# Hoe.plugin :website
# Hoe.plugin :cucumberfeatures

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec 'chimera' do
  self.developer 'Ben Myles', 'ben.myles@gmail.com'
  self.post_install_message = 'PostInstall.txt' # TODO remove if post-install message not required
  self.rubyforge_name       = self.name # TODO this is default value
  # self.extra_deps         = [['activesupport','>= 2.0.2']]
  self.extra_deps = [["activesupport","= 3.0.0.beta"],
    ["uuidtools","= 2.1.1"],
    ["activemodel",'= 3.0.0.beta'],
    ["yajl-ruby","= 0.7.4"],
    ["fast-stemmer", "= 1.0.0"],
    ["typhoeus", "= 0.1.22"]]
end

require 'newgem/tasks'
Dir['tasks/**/*.rake'].each { |t| load t }

# TODO - want other tests/tasks run by default? Add them to the list
# remove_task :default
# task :default => [:spec, :features]
