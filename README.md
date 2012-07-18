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

### Order

Once the code has been updated, tested and is ready for review, the order
can be placed which will create a new pull request:

`knife table order`

The order option will also optionally run foodcritic and require a passing
result before proceeding with the pull request generation.

### Service

Service works on the assumption that any new code into the stable branch (master
by default) will arrive via pull requests. By default, it will find the last
pull request in the log and update based on changes within that merge. The default
behavior of the `serve` command will upload and freeze any changed cookbooks. Optionally,
environments can be provided to have the cookbook versions automatically pegged. Also,
roles and data bags can be automatically uploaded as well.

Options for serve:

* `--environments ENV[,ENV...]` 'Update versions in given environments'
* `--git-autopush` 'Automatically commit and push any changes to master'
* `--git-tag` 'Automatically create tag for frozen cookbook'
* `--git-branch BRANCH` 'Set working branch'
* `--git-remote-name NAME` 'Remote repo name'
* `--git-autocommit` 'Automatically commit changes'
* `--autoproceed` 'Answer yes to any prompts'
* `--roles` 'Upload any changed roles'
* `--data-bags` 'Upload any changed data bags'
