#-*-ruby-*-

# Copyright 2012 Amazon.com, Inc. or its affiliates. All Rights
# Reserved.
# 
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy
# of the License is located at
#
#   http://aws.amazon.com/apache2.0/
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the
# specific language governing permissions and limitations under the
# License.

require 'fileutils'
require 'aws/ini'

module AWS

  # Provides methods to get various config values using the EB config
  # files and to write new settings.
  class ElasticBeanstalkConfig

    attr_reader :root_directory

    def initialize(root_directory)
      @root_directory = root_directory
    end

    EB_CONFIG_KEYS = {
      :region => "Region",
      :application_name => "ApplicationName",
      :environment_name => "EnvironmentName",
      :dev_tools_endpoint => "DevToolsEndpoint"
    }

    GIT_CONFIG_KEYS = {
      :region => "aws.region",
      :application_name => "aws.elasticbeanstalk.application",
      :environment_name => "aws.elasticbeanstalk.environment",
      :dev_tools_endpoint => "aws.elasticbeanstalk.host",
      :access_key_id => "aws.accesskey",
      :secret_access_key => "aws.secretkey"
    }

    EB_CONFIG_KEYS.each do |attr, eb_key|
      define_method(attr) do
        eb_config_settings[eb_key] || git_setting(GIT_CONFIG_KEYS[attr])
      end
    end

    CREDENTIAL_KEYS = {
      :access_key_id => "AWSAccessKeyId",
      :secret_access_key => "AWSSecretKey"
    }

    CREDENTIAL_KEYS.each do |attr, key|
      define_method(attr) do
        (credential_settings[key] unless credential_file.nil?) ||
          git_setting(GIT_CONFIG_KEYS[attr])
      end
    end

    KNOWN_REGIONS = ["us-east-1",
                     "us-west-1",
                     "us-west-2",
                     "eu-west-1",
                     "ap-northeast-1",
                     "ap-southeast-1",
                     "ap-southeast-2",
                     "sa-east-1"]

    def dev_tools_endpoint
      endpoing = nil
      if eb_config_settings["Region"]
        # Try to derive an endpoint from the EB config
        endpoint = eb_config_settings["DevToolsEndpoint"]
        endpoint ||= dev_tools_endpoint_default
      end

      # fall back to git settings if there's nothing in EB config
      endpoint || git_setting("aws.elasticbeanstalk.host")
    end

    def dev_tools_endpoint_default(region = self.region)
      "git.elasticbeanstalk.#{region}.amazonaws.com" if
        KNOWN_REGIONS.include?(region)
    end

    def branch_mappings
      eb_config_file["branches"]
    rescue Errno::ENOENT, Errno::EACCES
      {}
    end

    def write_settings(settings)
      eb_settings_to_write = {}
      credential_settings_to_write = {}
      settings.each do |key, value|

        eb_settings_to_write[EB_CONFIG_KEYS[key]] = value if
          EB_CONFIG_KEYS.include?(key)

      end

      FileUtils.mkdir_p(File.dirname(eb_config_file.filename))
      eb_config_file.write_settings("global",
                                    eb_settings_to_write) unless
        eb_settings_to_write.empty?

      if should_write_credential_file?
        FileUtils.mkdir_p(File.dirname(default_credential_file_path))
        INI.new(default_credential_file_path, false).
          write_settings("global",
                         CREDENTIAL_KEYS[:access_key_id] =>
                         settings[:access_key_id],
                         CREDENTIAL_KEYS[:secret_access_key] =>
                         settings[:secret_access_key])
        eb_config_file.
          write_settings("global", "AwsCredentialFile" => credential_file_path)
      end
    end

    def should_write_credential_file?
      !credential_file_configured? &&
        !ENV["HOME"].nil? &&
        !File.exists?(default_credential_file_path)
    end

    def credential_file_configured?
      !ENV["AWS_CREDENTIAL_FILE"].nil? || !eb_config_settings["AwsCredentialFile"].nil?
    end

    def credential_file_exists?
      File.exists?(credential_file_path) unless credential_file_path.nil?
    end

    def credential_file_readable?
      File.readable?(credential_file_path)
    end

    def credential_file_path
      ENV["AWS_CREDENTIAL_FILE"] ||
        eb_config_settings["AwsCredentialFile"] ||
        default_credential_file_path
    end

    def default_credential_file_path
      path = File.join(ENV["HOME"],
                       ".elasticbeanstalk",
                       "aws_credential_file") unless ENV["HOME"].nil?
    end

    private

    def credential_file
      @credential_file ||= INI.new(credential_file_path, false) if credential_file_exists?
    end

    def credential_settings
      credential_file["global"]
    rescue Errno::ENOENT, Errno::EACCES
      {}
    end

    def eb_config_file
      @eb_config_file ||=
        INI.new(File.join(root_directory,
                          ".elasticbeanstalk",
                          "config"))
    end

    def eb_config_settings
      eb_config_file["global"]
    rescue Errno::ENOENT, Errno::EACCES
      {}
    end

    def git_setting(key)
      value = `git config --get #{key}`.strip
      return nil if $?.exitstatus == 1
      value
    end

  end

end
