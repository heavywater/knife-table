module KnifeTable
  module Helpers
    def git
      @git ||= Git.open(File.dirname(cookbook_path))
    end
    
    def cookbook_path
      Chef::Config[:cookbook_path].first
    end
  end
end
