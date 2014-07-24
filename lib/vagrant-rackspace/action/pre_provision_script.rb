require "log4r"
require 'rbconfig'
require "vagrant/util/subprocess"

module VagrantPlugins
  module Rackspace
    module Action
      # This middleware allows you to run commands before normal provisioner is run
      class PreProvisionScript
        def initialize(app, env)
          @app    = app
          @logger = Log4r::Logger.new("vagrant_rackspace::action::sync_folders")
          @host_os = RbConfig::CONFIG['host_os']
        end

        def call(env)
          @app.call(env)
          ssh_info = env[:machine].ssh_info
          config   = env[:machine].provider_config
          pre_provision_script = config.pre_provision_script

          env[:ui].info(I18n.t("vagrant_rackspace.pre_provision_script_start"))

          scp_options = {}
          scp_options[:key_data] = IO.read(ssh_info[:private_key_path].first)
          fog_scp = Fog::SCP.new(ssh_info[:host], ssh_info[:username], scp_options)

          ssh_options = {}
          ssh_options[:key_data] = IO.read(ssh_info[:private_key_path].first)
          fog_ssh = Fog::SSH.new(ssh_info[:host], ssh_info[:username], ssh_options)

          workaround_script = File.expand_path(pre_provision_script)

          script_name = "/tmp/pre_prov_script_#{Time.now.to_i}.sh"

          fog_scp.upload(workaround_script.to_s, script_name)
          results = fog_ssh.run("sudo bash #{script_name}")
          stdout = results.map(&:stdout).join("\n")
          stderr = results.map(&:stderr).join("\n")
          env[:ui].info(stdout) unless stdout.empty?
          env[:ui].error(stderr) unless stderr.empty?
          env[:ui].info(I18n.t("vagrant_rackspace.pre_provision_script_finish"))
          results = fog_ssh.run("rm -rf #{script_name}")
        end
      end
    end
  end
end