# Used for forking upstream cookbooks
require 'knife-table/helpers'

module KnifeTable
  class TableRepair < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'hub'
    end

    banner 'knife table repair COOKBOOK[ COOKBOOK...]'

    option :create_repo,
      :short => '-C',
      :long => '--create-repository',
      :description => 'Create remote repository',
      :boolean => true,
      :default => false

    def run
      chef_p = github_project(git_origin)
      name_args.each do |cookbook|
        cookbook_p = github_project(submodule_url_for(cookbook))
        if(cookbook_p.username == chef_p.username)
          branch_submodule(cookbook)
        else
          forked_book = do_cookbook_fork(cookbook_p)
          realign_submodule_for(cookbook, forked_book)
        end
      end
    end

    def do_cookbook_fork(book)
      hub_api.fork_repo(
        github_project(remote_git_for(book))
      )
    end

    def realign_submodule_for(book, forked_book)
      delete_submodule("cookbook/#{book}")
      add_submodule(forked_book.git_url, "cookbook/#{book}")
    end
  end
end
