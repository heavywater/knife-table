require 'open3'
require 'knife-table/helpers'

module KnifeTable
  class TableOrder < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'hub'
    end

    banner 'knife table order [BRANCH]'

    option :upstream_user,
      :short => '-u USER',
      :long => '--upstream-user USER',
      :description => 'Username for upstream github account'

    option :upstream_branch,
      :short => '-b BRANCH',
      :long => '--upstream-branch BRANCH',
      :description => 'Upstream branch name',
      :default => 'master'

    option :title,
      :short => '-t TITLE',
      :long => '--title TITLE',
      :description => 'Title for pull request'
   

    def initialize(*args)
      super
      @upstream = config[:upstream_user]
      raise 'required' unless @upstream
    end

    def run
      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: Placing Order  **", [HighLine::GREEN, HighLine::BOLD])

      # TODO: Update this to not shell out
      cmd = "hub pull-request \"#{title}\" -b #{@upstream}:#{config[:upstream_branch]} -h #{local_user}:#{local_branch}"
      output = ''
      unless(File.exists?('/home/spox/config/.config'))
        g_config = Hub::GitHubAPI::Configuration.new(nil)
        g_user = g_config.prompt 'Github username'
        g_pass = g_config.prompt_password 'Github', g_user
      end
      res = Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
        if(g_user)
          stdin.puts g_user
          stdin.puts g_pass
        end
        output << stdout.readlines.last
        wait_thr.value
      end
      if(res.success)
        ui.msg "New pull request: #{output}"
      else
        ui.error "Failed to create pull request"
      end
    end

    private

    def title
      config[:title] || local_branch.gsub('_', ' ')
    end

    def local_branch
      unless(@branch)
        if(name_args.size > 0)
          @branch = name_args.first
        else
          @branch = git.current_branch
        end
      end
      @branch
    end

    def local_user
      unless(@local)
        l = %x{git remote -v}.split("\n").find_all{|r|
          r.include?('github.com')
        }.map{|r|
          Array(r.scan(%r{:[^/]+}).first).first
        }.compact.map{|r|
          r.sub(':', '')
        }.uniq.sort - [@upstream]
        if(l.size > 1)
          @local = ask_user_local(l)
        elsif(l.size < 1)
          @local = @upstream
        else
          @local = l.first
        end
      end
      @local
    end

    def ask_user_local(locals)
      l = nil
      ui.msg 'Please select your local user:'
      while(l.nil?)
        locals.each_with_index do |name, idx|
          ui.msg "#{idx + 1}. #{name}"
        end
        res = ui.ask_question "Enter number of local user [1-#{local.size}]:"
        if(locals[res.to_i + 1])
          l = locals[res.to_i + 1]
        else
          ui.warn "Invalid selection."
        end
      end
      l
    end

  end
end
