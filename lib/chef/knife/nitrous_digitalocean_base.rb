require 'app_conf'
require 'slack-notifier'

class Chef
  class Knife
    module NitrousDigitalOceanBase
      def self.included(includer)
        includer.class_eval do
          deps do
            require 'droplet_kit'
            require 'yaml'
            require 'servers/droplet'
          end
        end
      end

      def client
        DropletKit::Client.new(access_token: Chef::Config[:knife][:digitalocean_access_token])
      end

      def validate!(keys = [:digitalocean_access_token])
        errors = []

        keys.each do |k|
          if locate_config_value(k).nil?
            errors << "You did not provide a valid '#{k}' value. Please set knife[:#{k}] in your knife.rb."
          end
        end

        if errors.each { |e| ui.error(e) }.any?
          exit 1
        end
      end

      def locate_config_value(key)
        key = key.to_sym
        config[key] || Chef::Config[:knife][key]
      end

      def wait_for_status(result, status: 'in-progress', sleep: 3)
        print 'Waiting '
        while result.status == 'in-progress' do
          sleep sleep
          print('.')

          if status == 'in-progress'
            break if client.droplets.find(id: locate_config_value(:id)).status != 'in-progress'
          else
            break if client.droplets.find(id: locate_config_value(:id)).status == status
          end
        end
        ui.info 'OK'
      end

      def parse(config_file)
        return nil unless File.exists? config_file

        parsed_yaml = nil

        begin
          parsed_yaml = YAML.load(File.read(config_file))
        rescue Psych::SyntaxError
          p "Invalid YAML. Check your #{config_file} file."
          return nil
        end

        if parsed_yaml["servers_common"]
          server_config = deep_merge parsed_yaml["servers_common"], server_config
        end

        KnifeNitrous::Droplet.new(name: server_config['hostname'],
                                  size: server_config['do_size'],
                                  region: server_config['do_region'],
                                  image:  server_config['do_image'],
                                  attributes: server_config['attributes'],
                                  run_list: parsed_yaml['run_list'])
      end

      def nitrous_config
        return @nitrous_config if @nitrous_config

        @nitrous_config = AppConf.new
        load_paths = [File.expand_path('~/.chef/nitrous.yml'), File.expand_path('./nitrous.yml')]
        load_paths.each do |load_path|
          if File.exists?(load_path)
            @nitrous_config.load(load_path)
          end
        end

        @nitrous_config
      end

      def announce(message, level: :info)
        term_color = case level
        when :error, :warn
          :red
        when :success
          :green
        when :info
          :magenta
        else
          :magenta
        end

        puts "===> #{ui.color(message, term_color)}"
        if slack_enabled?
          token = case level
          when :error, :warn
            '(ಠ_ಠ)'
          when :success
            '✌(-‿-)✌'
          else
            '(⌐■_■)'
          end
          slack_client.ping("#{message} #{token}")
        end
      end

      def slack_enabled?
        nitrous_config.slack && nitrous_config.slack[:enabled]
      end

      def slack_client
        @slack_client ||= Slack::Notifier.new(nitrous_config.slack[:webhook])
      end

      def bootstrap_for_node(droplet, ip_address)
        bootstrap = bootstrap_class.new
        bootstrap.name_args = [ip_address]
        bootstrap.config[:chef_node_name] = droplet.name
        bootstrap.config[:ssh_port] = Chef::Config[:knife][:ssh_port] || droplet.ssh_port
        bootstrap.config[:use_sudo] = true unless droplet.ssh_user == 'root'
        bootstrap.config[:first_boot_attributes] = droplet.attributes || {}
        bootstrap
      end

      def bootstrap_class
        solo_bootstrap? ? Chef::Knife::SoloBootstrap : Chef::Knife::Bootstrap
      end

    end
  end
end
