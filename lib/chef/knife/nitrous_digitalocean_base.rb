# Copied from knife-digital_ocean
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
class Chef
  class Knife
    module NitrousDigitalOceanBase
      def self.load_deps
        require 'droplet_kit'
        require 'json'
      end

      def self.included(includer)
        includer.class_eval do
          category 'digital_ocean'

          deps { Chef::Knife::NitrousDigitalOceanBase.load_deps }

          option :digital_ocean_access_token,
                 short: '-A ACCESS_TOKEN',
                 long: '--digital_ocean_access_token ACCESS_TOKEN',
                 description: 'Your DigitalOcean ACCESS_TOKEN',
                 proc: proc { |access_token| Chef::Config[:knife][:digital_ocean_access_token] = access_token }
        end
      end

      def client
        DropletKit::Client.new(access_token: Chef::Config[:knife][:digital_ocean_access_token])
      end

      def validate!(keys = [:digital_ocean_access_token])
        errors = []

        keys.each do |k|
          if locate_config_value(k).nil?
            errors << "You did not provide a valid '#{k}' value. Please set knife[:#{k}] in your knife.rb or pass as an option."
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
    end
  end
end
