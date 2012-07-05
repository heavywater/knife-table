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
      :description => 'Set prefix for branch name',
      :default => 'WIP-'

    option :bump_type,
      :short => '-b TYPE',
      :long => '--bump-type TYPE',
      :description => 'Type of version bump (major, minor, patch)',
      :default => 'patch'

    def initialize(*args)
      super
      @cookbooks = config[:cookbooks].to_s.split(',').map(&:strip)
    end

    def run
      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: New place setting  **", [HighLine::GREEN, HighLine::BOLD])
      branch_name = "#{config[:branch_prefix]}#{name_args.join('_').downcase}"
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
    end

  end
end
