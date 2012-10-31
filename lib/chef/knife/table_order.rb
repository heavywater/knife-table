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
      :description => 'Upstream branch name'

    option :title,
      :short => '-t TITLE',
      :long => '--title TITLE',
      :description => 'Title for pull request'

    option :foodcritic,
      :short => '-f',
      :long => '--foodcritic',
      :description => 'Pass foodcritic before generating pull request',
      :boolean => true

    option :kitchen,
      :short => '-k',
      :long => '--kitchen',
      :description => 'Pass test-kitchen before generating pull request',
      :boolean => false

    option :use_bundler,
      :long => '--use-bundler',
      :description => 'Run testing commands using `bundle exec`',
      :boolean => false

    option :foodcritic_fail_on,
      :short => '-x correctness,any,~FC014',
      :long => '--foodcritic-fail-on correctness,any,~FC014',
      :description => 'Set what foodcritic should fail on',
      :proc => lambda{|v| v.split(',').strip}


    def run
      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: Placing Order  **", [HighLine::GREEN, HighLine::BOLD])
      check_config_options
      be = 'bundle exec ' if config[:use_bundler]
      if(config[:foodcritic])
        fail_on = Array(config[:foodcritic_fail_on]).map{|s| "-f #{s}"}.join(' ')
        cookbooks = discover_changed(:cookbooks, 'master', 'HEAD').map{|c| c.split('/').first}
        pass = true
        cookbooks.each do |cookbook|
          res = system("#{be}foodcritic #{fail_on} #{File.join(cookbook_path, cookbook)}")
          pass = res unless res
        end
        unless(pass)
          ui.fatal "Modifications do not currently pass foodcritic!"
          exit 1
        end
      end

      if(config[:kitchen])
        cookbooks = discover_changed(:cookbooks, 'master', 'HEAD').map{|c| c.split('/').first}
        pass = true
        cwd = Dir.pwd
        cookbooks.each do |cookbook|
          cpath = File.join(cookbook_path, cookbook)
          Dir.chdir(cpath)
          res = system("#{be}kitchen test --teardown")
          pass = res unless res
        end
        Dir.chdir(cwd)
        unless(pass)
          ui.fatal "Modifications do not currently pass test-kitchen!"
          exit 1
        end
      end

      hub_runner = Hub::Runner.new(
        'pull-request', title, '-b', "#{@upstream}:#{config[:upstream_branch]}",
        '-h', "#{user_for_local}:#{local_branch}"
      )
      hub_runner.execute
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

    def check_config_options
      %w(upstream_user upstream_branch title foodcritic foodcritic_fail_on).each do |key|
        config[key.to_sym] ||= Chef::Config[:knife]["table_order_#{key}".to_sym]
      end
      @upstream = config[:upstream_user]
      unless(@upstream)
        ui.fatal "Upstream user is REQUIRED"
        exit 1
      end
      config[:foodcritic_fail_on] ||= 'correctness'
      config[:upstream_branch] ||= 'master'
    end
  end
end
