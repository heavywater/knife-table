# KnifeTable

KnifeTable is a knife plugin to aid in cookbook development
workflow. Its intention is to help automate versioning
within environments and cookbook freezing based on a stable
branch. Building off of the knife-spork plugin KnifeTable
helps to provide consistency within the environment.


## Usage

Currently, the supported workflow is as follows:

`knife table set`

`knife table order`


and 

`knife table serve`

### Setting the table

First, we set the table either by adding new or modifying
existing features. To do this, we set the table with a basic description
of what is being added:

`knife table set new feature`

This will create a new working branch named 'new_feature'. A default prefix
can be added the branch name via the `-p` option. If it is known what cookbooks 
will be modified, you can provide them while setting:

`knife table set -c iptables,mysql new feature`

Options
-------

* 'Automatically bump patch version on provided cookbooks'
  * '-c [COOKBOOK,COOKBOOK,...]'
  * '--cookbooks [COOKBOOK,COOKBOOK,...]'

* 'Set prefix for branch name'
  * knife config: :table_set_branch_prefix
  * '-p PREFIX'
  * '--branch-prefix PREFIX'

* 'Type of version bump (major, minor, patch)'
  * knife config: :table_set_bump_type
  * '-b TYPE'
  * '--bump-type TYPE'

### Order

Once the code has been updated, tested and is ready for review, the order
can be placed which will create a new pull request:

`knife table order`

The order option will also optionally run foodcritic and require a passing
result before proceeding with the pull request generation.

Options
-------

* 'Username for upstream github account'
  * knife config: :table_order_upstream_user
  * '-u USER'
  * '--upstream-user USER'

* 'Upstream branch name'
  * knife config: :table_order_upstream_branch
  * '-b BRANCH'
  * '--upstream-branch BRANCH'

* 'Title for pull request'
  * knife config: :table_order_title
  * '-t TITLE'
  * '--title TITLE'

* 'Pass foodcritic before generating pull request'
  * knife config: :table_order_foodcritic
  * '-f'
  * '--foodcritic'

* 'Set what foodcritic should fail on'
  * knife config: :table_order_foodcritic_fail_on
  * '-x correctness,any,~FC014'
  * '--foodcritic-fail-on correctness,any,~FC014'

### Service

Service works on the assumption that any new code into the stable branch (master
by default) will arrive via pull requests. By default, it will find the last
pull request in the log and update based on changes within that merge. The default
behavior of the `serve` command will upload and freeze any changed cookbooks. Optionally,
environments can be provided to have the cookbook versions automatically pegged. Also,
roles and data bags can be automatically uploaded as well.

Options
-------

* 'Update versions in given environments'
  * knife config: :table_serve_environments
  * '-e ENV[,ENV...]'
  * '--environments ENV[,ENV...]'

* 'Automatically commit and push any changes to master'
  * knife config: :table_serve_git_autopush
  * '-g'
  * '--git-autopush'

* 'Automatically create tag for frozen cookbook'
  * knife config: :table_serve_git_tag
  * '-t'
  * '--git-tag'

* 'Set working branch'
  * knife config: :table_serve_git_branch
  * '-b BRANCH'
  * '--git-branch BRANCH'

* 'Remote repo name'
  * knife config: :table_serve_git_remote_name
  * '-r NAME'
  * '--git-remote-name NAME'

* 'Automatically commit changes'
  * knife config: :table_serve_git_autocommit
  * '-c'
  * '--git-autocommit'

* 'Answer yes to any prompts'
  * knife config: :table_serve_autoproceed
  * '-a'
  * '--autoproceed'

* 'Upload any changed roles'
  * knife config: :table_serve_upload_roles
  * '-r'
  * '--roles'

* 'Upload any changed data bags'
  * knife config: :table_serve_upload_data_bags
  * '-d'
  * '--data-bags'
