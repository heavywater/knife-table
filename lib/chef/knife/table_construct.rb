require 'knife-table/helpers'

module KnifeTable
  class TableConstruct < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'hub'
      require 'ostruct'
    end

    banner 'knife table construct COOKBOOK [REPO]'

    option :create_repo,
      :short => '-C',
      :long => '--create-repository',
      :description => 'Create remote repository',
      :boolean => true,
      :default => false

    option :default_upstream_account,
      :short => '-U NAME',
      :long => '--default-upstream NAME',
      :description => 'Default upstream name',
      :default => 'hw-cookbooks'

    option :fork_upstream,
      :short => '-F',
      :long => '--fork-upstream',
      :description => 'Create a local fork of upstream repository',
      :boolean => true,
      :default => false

    def run
      enforce_repo_root!
      ui.msg ui.highline.color(
        "#{' ' * 10}** Knife Table: Constructing Table **",
        [HighLine::GREEN, HighLine::BOLD]
      )
      git_url = if(config[:create_repo])
        create_repo! if config[:create_repo]
      else
        name_args.last
      end
      if(config[:fork_upstream] && !config[:create_repo])
        hub_api.fork_repo(
          OpenStruct.new(
            :host => 'github.com',
            :owner => config[:default_upstream_account],
            :name => name_args.first
          )
        )
        new_project = github_project(name_args.first, user_for_local)
        git_url = new_project.git_url
      end
      submodule_add(git_url, "cookbooks/#{name_args.first}")
    end

    def create_repo!
      api = Hub::Commands.api_client
      new_project = github_project(name_args.first, user_for_local)
      api.create_repo(new_project)
      new_project.git_url(:private => true)
    end
  end
end
