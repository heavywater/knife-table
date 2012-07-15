module KnifeTable
  module Helpers
    def git
      @git ||= Git.open(File.dirname(cookbook_path))
    end
    
    def cookbook_path
      Chef::Config[:cookbook_path].first
    end

    def discover_changed(type, first_commit, last_commit)
      changed = []
      git.diff(first_commit, last_commit).stats[:files].keys.each do |path|
        if(path.start_with?(type.to_s))
          changed << path.sub(/^#{type.to_s}\/?/, '')
        end
      end
      changed.uniq
    end
  end
end
