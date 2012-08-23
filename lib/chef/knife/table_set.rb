require 'knife-table/helpers'
require 'knife-table/../chef/knife/table_serve.rb'

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
      user = ENV['OPSCODE_USER'] || ENV['USER']
      path = cookbook_path.gsub("cookbooks", "environments") + "/#{user}.json"
      cookbooks = discover_changed(:cookbooks, span[0], span[1]).map{|c| c.split('/').first}

      unless(File.exists?(path))
        ui.highline.say "Creating user environment for #{ui.highline.color(user, HighLine::BLUE)} "
        env = JSON.parse(IO.read(path.gsub("#{user}.json", "production.json")))
        env.name(user)
        File.new(path, 'w').write(env.to_json)
        ui.highline.say "... done\n\n#{ui.highline.color(user, HighLine::BLUE)}: "
        unless(cookbooks.empty?)
          cookbooks.each{|c| serve.update_environments(user, c) }
          ui.highline.say "\n"
        end
      else
        ui.highline.say " #{ui.highline.color(user, HighLine::BLUE)}: "
        unless(cookbooks.empty?)
          cookbooks.each{|c| serve.update_environments(user, c) }
          ui.highline.say "\n"
        end
      end
    end

    private

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
