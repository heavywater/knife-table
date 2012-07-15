require 'knife-table/helpers'

module KnifeTable
  class TableClear < Chef::Knife

    include KnifeTable::Helpers

    deps do
      require 'git'
      require 'chef/knife/core/object_loader'
    end

    banner 'knife table clear'

    def run
      ui.fatal "Not currently supported"
    end

  end
end

