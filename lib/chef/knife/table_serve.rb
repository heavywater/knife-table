require 'knife-table/helpers'

module KnifeTable
  class TableServe < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'chef/knife/core/object_loader'
    end

    banner "knife table serve [#PULLREQ|COMMITSHA[..COMMITSHA]]"

    option :environments,
      :short => '-e ENV[,ENV...]',
      :long => '--environments ENV[,ENV...]',
      :description => 'Update versions in given environments'

    option :git_autopush,
      :short => '-g',
      :long => '--git-autopush',
      :boolean => true,
      :description => 'Automatically commit and push any changes to master'

    option :git_tag,
      :short => '-t',
      :long => '--git-tag',
      :boolean => true,
      :description => 'Automatically create tag for frozen cookbook'

    option :git_branch,
      :short => '-b BRANCH',
      :long => '--git-branch BRANCH',
      :description => 'Set working branch'

    option :git_remote_name,
      :short => '-r NAME',
      :long => '--git-remote-name NAME',
      :description => 'Remote repo name'

    option :git_autocommit,
      :short => '-c',
      :long => '--git-autocommit',
      :boolean => true,
      :description => 'Automatically commit changes'

    option :autoproceed,
      :short => '-a',
      :long => '--autoproceed',
      :boolean => true,
      :description => 'Answer yes to any prompts'

    option :upload_roles,
      :short => '-r',
      :long => '--roles',
      :boolean => true,
      :description => 'Upload any changed roles'

    option :upload_data_bags,
      :short => '-d',
      :long => '--data-bags',
      :boolean => true,
      :description => 'Upload any changed data bags'

    def run
      check_config_options
      sanity_checks
      cookbooks = discover_changed(:cookbooks, *determine_commit_span).map{|c|c.split('/').first}
      roles = discover_changed(:roles, *determine_commit_span) if config[:upload_roles]
      data_bags = discover_changed(:data_bags, *determine_commit_span) if config[:upload_data_bags]

      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: Service started  **", [HighLine::GREEN, HighLine::BOLD])
      ui.highline.say ui.highline.color("Discovered cookbooks staged for freeze: #{cookbooks.join(', ')}", HighLine::CYAN) unless cookbooks.nil? || cookbooks.empty?
      ui.highline.say ui.highline.color("Environments staged to be updated: #{@environments.join(', ')}", HighLine::CYAN) unless @environments.empty?
      ui.highline.say ui.highline.color("Roles staged to be uploaded: #{roles.sort.map{|r|r.sub(/\.(rb|json)/, '')}.join(', ')}", HighLine::CYAN) unless roles.nil? || roles.empty?
      ui.highline.say ui.highline.color("Data Bags staged to be uploaded: #{data_bags.sort.join(', ')}", HighLine::CYAN) unless data_bags.nil? || data_bags.empty?

      ui.highline.say "\n"

      if(config[:autoproceed])
        ui.warn "Autoproceeding based on config (ctrl+c to halt)"
        sleep(3)
      else
        ui.confirm "Proceed"
      end
      
      ui.highline.say "\n"

      ui.highline.say "#{ui.highline.color("Freezing cookbooks:", HighLine::GREEN)} "
      cookbooks.each{|c| freeze_cookbook(c) }
      ui.highline.say "\n"

      unless(@environments.empty?)
        ui.msg ui.highline.color("Updating environments:", HighLine::GREEN)
        @environments.each do |env|
          ui.highline.say "  #{ui.highline.color(env, HighLine::BLUE)}: "
          cookbooks.each{|c| update_environments(env, c) }
          ui.highline.say "\n"
        end

        ui.highline.say "#{ui.highline.color("Uploading environments:", HighLine::GREEN)} "
        upload_environments
        ui.highline.say "\n"
      end

      upload_changes(:roles, roles) if roles && !roles.empty?
      upload_changes(:data_bags, data_bags) if data_bags && !data_bags.empty?

      if(config[:git_autocommit])
        ui.highline.say "#{ui.highline.color("Committing environments:", HighLine::GREEN)} "
        git_commit_environments(cookbooks)
        ui.highline.say "\n"
      end

      if(config[:git_tag])
        ui.highline.say "#{ui.highline.color("Tagging cookbooks:", HighLine::GREEN)} "
        git_tag(cookbooks)
        ui.highline.say "\n"
      end

      if(config[:git_autopush])
        ui.highline.say "#{ui.highline.color("Pushing changes to remote repo:", HighLine::GREEN)} "
        git_push
        ui.highline.say "\n"
      end

      ui.msg ui.highline.color("#{' ' * 10}** Knife Table: Service complete **", [HighLine::GREEN, HighLine::BOLD])
    end

    def frozen_cookbook?(cookbook)
      begin
        spork_check = KnifeSpork::SporkCheck.new
        spork_check.check_frozen(
          cookbook,
          spork_check.get_version(
            cookbook_path,
            cookbook
          )
        )
      rescue  Net::HTTPServerException => e
        if(e.response.is_a?(Net::HTTPNotFound))
          false
        else
          raise
        end
      end
    end

    def freeze_cookbook(cookbook)
      unless(frozen_cookbook?(cookbook))
        spork_upload = KnifeSpork::SporkUpload.new
        spork_upload.config[:freeze] = true
        spork_upload.config[:cookbook_path] = cookbook_path
        repo_cookbook = spork_upload.cookbook_repo[cookbook]
        repo_cookbook.freeze_version
        Chef::CookbookUploader.new(repo_cookbook, cookbook_path).upload_cookbook
        ui.highline.say "#{cookbook} "
      else
        ui.highline.say "#{ui.highline.color("#{cookbook} (already frozen)", HighLine::RED)} "
      end
    end

    def update_environments(environment, cookbook)
      promote_environment(environment, cookbook)
      ui.highline.say "#{cookbook} "
    end

    def upload_environments
      @environments.each do |environment|
        spork_promote.config[:cookbook_path] = [cookbook_path]
        spork_promote.save_environment_changes_remote(environment)
        ui.highline.say "#{environment} "
      end
    end

    def git_commit_environments(cookbooks)
      commit = false
      @environments.each do |environment|
        status = git.status.changed[::File.join('environments', "#{environment}.json")]
        if(status && !git.diff('HEAD', status.path).none?)
          git.add(status.path)
          commit_message = "Environment #{environment} cookbook version updates\n"
          cookbooks.sort.each do |cookbook|
            commit_message << "\n#{cookbook}: #{spork_promote.get_version(cookbook_path, cookbook)}"
          end
          git.commit(commit_message)
          ui.highline.say "#{environment} "
          @git_changed = true
          commit = true
        end
      end
      ui.highline.say "nothing to commit " unless commit
    end

    def git_tag(cookbooks)
      cookbooks.each do |cookbook|
        tag_string = "#{cookbook}-v#{spork_promote.get_version(cookbook_path, cookbook)}"
        unless(git.tags.map(&:name).include?(tag_string))
          git.add_tag(tag_string)
          ui.highline.say "#{tag_string} "
          @git_changed = true
        else
          ui.highline.say "#{ui.highline.color("#{tag_string} (exists)", HighLine::RED)} "
        end
      end
    end

    def git_push
      if(@git_changed)
        git.push(config[:git_remote_name], config[:git_branch], true)
        ui.highline.say "pushed #{config[:git_branch]} to #{config[:git_remote_name]} "
      else
        ui.highline.say "nothing to push "
      end
    end

    def upload_roles(role)
      role_load = loader(:roles).load_from('roles', role)
      role_load.save
      role_load
    end

    def upload_data_bags(bag)
      data_bag_load = loader(:data_bags).load_from('data_bags', bag.split('/').first, bag.split('/').last)
      dbag = Chef::DataBagItem.new
      dbag.data_bag(bag.split('/').first)
      dbag.raw_data = data_bag_load
      dbag.save
      dbag
    end

    private

    def promote_environment(environment, cookbook)
      version = spork_promote.get_version(cookbook_path, cookbook)
      env = spork_promote.update_version_constraints(
        Chef::Environment.load(environment), 
        cookbook, 
        version
      )
      env_json = spork_promote.pretty_print(env)
      spork_promote.save_environment_changes(environment, env_json)
    end

    def spork_promote
      unless(@spork_promote)
        @spork_promote = KnifeSpork::SporkPromote.new
        @spork_promote.config[:cookbook_path] = [cookbook_path]
        @spork_promote.loader # work around for bad namespacing
        @spork_promote.instance_variable_set(:@conf, AppConf.new) # configuration isn't isolated to single call so just stub
      end
      @spork_promote
    end

    def sanity_checks
      unless(git.branches.map(&:name).include?(config[:git_branch]))
        raise "Requested git branch (#{config[:git_branch]}) does not exist"
      else
        ui.warn "Checking out requested working branch: #{config[:git_branch]}"
        @git.checkout(config[:git_branch]) if config[:git_branch]
      end
      unless(git.remotes.map(&:name).include?(config[:git_remote_name]))
        raise "Specified remote #{config[:git_remote_name]} not found"
      end
    end

    def determine_commit_span
      if(@first_commit.nil? || @last_commit.nil?)
        if(name_args.size > 0)
          if(name_args.first.start_with?('#'))
            @first_commit, @last_commit = discover_commits(name_args.first)
          elsif(name_args.first.include?(".."))
            @first_commit, @last_commit = name_args.first.split("..")
          else
            @first_commit = "#{name_args.first}^1"
            @last_commit = name_args.first
          end
        else
          @first_commit, @last_commit = discover_commits
        end
      end
      [@first_commit, @last_commit]
    end

    def discover_commits(pull_num = nil)
      match = "pull request #{pull_num}"
      commit = git.log.detect{|log| log.message.include?(match)}
      if(commit)
        ["#{commit}^1",commit]
      else
        raise "Unable to locate last pull request"
      end
    end

    def upload_changes(type, changed)
      raise "Unsupported upload change type: #{type}" unless [:roles, :data_bags].include?(type.to_sym)
      ui.highline.say "#{ui.highline.color("Uploading #{type.to_s.gsub('_', ' ')}:", HighLine::GREEN)} "
      unless(changed.empty?)
        changed.each do |item|
          thing = send("upload_#{type}", item)
          ui.highline.say "#{thing.is_a?(Chef::Role) ? thing.name : "#{thing.data_bag}::#{thing.id}"} "
        end
      else
        ui.highline.say "no #{type.to_s.gsub('_', ' ').sub(/s$/, '')} changes detected "
      end
      ui.highline.say "\n"
    end

    def loader(type)
      if(type == :roles)
        @role_loader ||= Chef::Knife::Core::ObjectLoader.new(Chef::Role, ui)
      elsif(type == :data_bags)
        @databag_loader ||= Chef::Knife::Core::ObjectLoader.new(Chef::DataBagItem, ui)
      else
        raise 'Unsupported load type'
      end
    end

    def check_config_options
      %w(environments git_autopush git_tag git_branch git_remote_name 
        git_autocommit autoproceed upload_roles upload_data_bags).each do |key|
        config[key.to_sym] ||= Chef::Config[:knife]["table_serve_#{key}".to_sym]
      end
      @environments = config[:environments].is_a?(Array) ? config[:environments] : config[:environments].to_s.split(",").map(&:strip)
      config[:git_branch] ||= 'master'
      config[:git_remote_name] ||= 'origin'
    end
  end
end
