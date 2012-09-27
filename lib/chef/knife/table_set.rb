require 'knife-table/helpers'

module KnifeTable
  class TableSet < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'chef/knife/core/object_loader'
    end

    banner 'knife table set NEW_FEATURE_OR_FIX'

    option :cookbooks,
      :short => '-c [COOKBOOK,COOKBOOK,...]',
      :long => '--cookbooks [COOKBOOK,COOKBOOK,...]',
      :description => 'Automatically bump patch version on provided cookbooks'

    option :branch_prefix,
      :short => '-p PREFIX',
      :long => '--branch-prefix PREFIX',
      :description => 'Set prefix for branch name'

    option :bump_type,
      :short => '-b TYPE',
      :long => '--bump-type TYPE',
      :description => 'Type of version bump (major, minor, patch)'

    def run
      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: New place setting  **", [HighLine::GREEN, HighLine::BOLD])
      if(name_args.empty?)
        ui.fatal "Feature description must be provided"
        exit 1
      end
      check_config_options
      check_current_branch!
      check_up_to_date!
      branch_name = "#{config[:branch_prefix]}#{name_args.join('_').downcase}"
      check_branch_conflict!(branch_name)
      ui.highline.say "Creating new work branch (#{branch_name}): "
      git.branch(branch_name).create
      ui.highline.say "done"
      git.checkout(branch_name)

      unless(@cookbooks.empty?)
        bumper = KnifeSpork::SporkBump.new
        @cookbooks.each do |cookbook|
          bumper.patch(cookbook_path, cookbook, config[:bump_type])
        end
      end

      serve = KnifeTable::TableServe.new
      span = serve.determine_commit_span
      path = cookbook_path.gsub("cookbooks", "environments") + "/#{branch_name}.json"

      unless(File.exists?(path))
        ui.highline.say "Creating local environment #{ui.highline.color(branch_name, HighLine::BLUE)} "
        if(File.exists?(path.gsub("#{branch_name}.json", "production.json")))
          env = JSON.parse(IO.read(path.gsub("#{branch_name}.json", "production.json")))
        else
          ui.highline.say "\n#{ui.highline.color('No production environment found ... terminating', HighLine::RED)}"
          exit 1
        end
        env.name(branch_name)
        if(Chef::Environment.list.include?(branch_name))
          ui.highline.say "\n#{ui.highline.color('WARN', HighLine::RED)}: environment exists on server"
        end
        environment_copy(env, path)
        ui.highline.say "... done\n\n#{ui.highline.color(env.name, HighLine::BLUE)}: "
        unless(@cookbooks.empty?)
          @cookbooks.each{|c| serve.update_environments(env.name, c) }
          ui.highline.say "\n"
        end
      else
        ui.highline.say "#{ui.highline.color(branch_name, HighLine::BLUE)}: "
        unless(@cookbooks.empty?)
          @cookbooks.each{|c| serve.update_environments(branch_name, c) }
          ui.highline.say "\n"
        end
      end
    end

    private

    def environment_copy(environment, path)
      f = File.open(path, 'w')
      f.write(environment.to_json + "\n")
      f.close
    end

    def check_current_branch!
      unless(git.current_branch == 'master')
        ui.fatal "Set requires master branch to be checked out. Currently on: #{git.current_branch}"
        exit 1
      end
    end

    def check_branch_conflict!(name)
      conflict = git.branches.map(&:full).detect do |b|
        b == name || b.sub(%r{remotes/[^/]+/}, '') == name
      end
      if(conflict)
        ui.fatal "Failed to create topic branch. Already exists: #{conflict}"
        exit 1
      end
    end

    def check_up_to_date!
      # TODO: fetch/merge master to ensure up to date?
    end

    def check_config_options
      %w(cookbooks branch_prefix bump_type).each do |key|
        config[key.to_sym] ||= Chef::Config[:knife]["table_set_#{key}".to_sym]
      end
      @cookbooks = config[:cookbooks].to_s.split(',').map(&:strip)
      config[:bump_type] ||= 'patch'
    end

  end
end
