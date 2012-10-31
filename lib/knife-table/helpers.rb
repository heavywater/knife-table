require 'ostruct'

module KnifeTable
  class QuestionableOpenStruct < OpenStruct
    def method_missing(*args)
      if(args.first.to_s.end_with?('?'))
        !!self.send(args.first.to_s.sub('?', ''))
      else
        super
      end
    end
  end

  module Helpers

    def repo_dir
      File.dirname(cookbook_path)
    end

    def enforce_repo_root!
      unless(File.expand_path(repo_dir) == File.expand_path(Dir.pwd))
        raise 'You must be at the root of the chef repo!'
      end
    end

    def git
      @git ||= Git.open(repo_dir)
    end

    def git_origin
      @git.remotes.detect{|r|
        r.name == 'origin'
      }.url
    end

    def submodule_url_for(path)
      mods = File.readlines('.gitmodules')
      key = mods.find_index{|m| m.include?(path)}
      if(key)
        mods[key+2].split('=').last.strip
      else
        raise "Failed to locate requested submodule: #{path}"
      end
    end

    def user_for_local(remote=nil)
      unless(@local)
        if(git.remotes.size > 1 && remote.nil?)
          ui.msg 'Please select your local user:'
          while(remote.nil?)
            git.remotes.each_with_index do |name, idx|
              ui.msg "#{idx + 1}. #{name}"
            end
            res = ui.ask_question "Enter number of local user [1-#{git.remotes.size}]:"
            if(git.remotes[res.to_i - 1])
              remote = git.remotes[res.to_i - 1]
            else
              ui.warn "Invalid selection."
            end
          end
        else
          remote = git.remotes.first
        end
        @local = remote.url.scan(
          %r{//.+[/:](.+?)/}
        ).flatten.first
      end
      @local
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

    def hub_api
      @_hub_api ||= Hub::Commands.send(:api_client)
    end

    def delete_submodule(path)
      # .gitmodules
      m_file = File.readlines('.gitmodules')
      key = m_file.find_index{|l| l.include?(path) }
      if(key)
        m_file.slice!(key, 3)
        File.open('.gitmodules', 'w') do |file|
          file.puts m_file.join
        end
      end
      # .git/config
      c_file = File.readlines('.git/config')
      key = c_file.find_index{|l| l.include?(path) }
      if(key)
        c_file.slice!(key, 2)
        File.open('.git/config') do |file|
          file.puts c_file.join
        end
      end
      # cookbooks/path
      FileUtils.rm_rf(path)
    end

    def github_project(project)
      parts = project.scan(%r{.+(://|@)(^[/]+)[:/]([^/]+)/(.+)}).first
      if(parts)
        prog = QuestionableOpenStruct.new(
          :git_url => project,
          :host => parts[1],
          :user => parts[2],
          :projects => parts[3]
        )
        prog.github = prog.host == 'github.com'
      else
        raise 'Not a proper git remote project'
      end
    end

    def add_submodule(path, url)
      Hub::Runner.new(
        'submodule', 'add', url, path)
      ).execute
  end
end
