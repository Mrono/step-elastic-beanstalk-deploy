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

require 'openssl'
require 'aws/elastic_beanstalk_config'

module AWS
  module DevTools

    @@beanstalk_config = nil
    def beanstalk_config
      @@beanstalk_config ||= ElasticBeanstalkConfig.new(Dir.pwd)
    end
    module_function :beanstalk_config

    def commit_exists?(commit)
      id = %x{git rev-parse #{commit}}.strip
      $?.exitstatus == 0
    end
    module_function :commit_exists?

    def git_object_type(commit)
      %x{git cat-file -t #{commit}}.strip
    end
    module_function :git_object_type

    def commit_id(commit)
      commit ||= "HEAD"
      id = %x{git rev-parse #{commit}}.strip
      unless "commit" == (type = git_object_type(commit))
        raise "#{commit} is a #{type}, and the value of --commit must refer to a commit"
      end
      raise "Unable to find revision #{commit}" unless $? == 0
      id
    end
    module_function :commit_id

    def host()
      beanstalk_config.dev_tools_endpoint.split(":")[0]
    end
    module_function :host

    def port()
      beanstalk_config.dev_tools_endpoint.split(":")[1]
    end
    module_function :port

    def repo()
      beanstalk_config.application_name
    end
    module_function :repo

    def headers(date)
      [date, beanstalk_config.region, "devtools", "aws4_request"]
    end
    module_function :headers

    def to_hex(str)
      str.to_s.unpack("H*").first
    end
    module_function :to_hex

    def sha256(str)
      OpenSSL::Digest.hexdigest("sha256", str)
    end
    module_function :sha256

    def hmac(d,s)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new("sha256"), s, d)
    end
    module_function :hmac

    def environment()
      current_branch = %x(git rev-parse --abbrev-ref HEAD)
      raise "Error looking up current branch." unless $? == 0
      current_branch.chomp!
      if (current_branch == "HEAD")
        # HEAD doesn't point to a branch, so we'll fall back to default.
        return nil
      end
      beanstalk_config.branch_mappings[current_branch]
    end
    module_function :environment

    def signed_uri env, commit
      time = Time.now.utc.strftime("%Y%m%dT%H%M%S")
      date = time[0..7]

      env ||= environment || beanstalk_config.environment_name
      secret_key = beanstalk_config.secret_access_key
      raise "Unable to find AWS Secret Key. Please run git aws.config to add it." if secret_key.nil? or secret_key.empty?
      access_key = beanstalk_config.access_key_id
      raise "Unable to find AWS Access Key. Please run git aws.config to add it." if access_key.nil? or access_key.empty?

      path = "/v1/repos/#{to_hex repo}/commitid/#{to_hex(commit_id(commit))}"
      path += "/environment/#{to_hex env}" unless env.nil? || env.empty?

      request_signature = sha256 "GIT\n#{path}\n\nhost:#{host}\n\nhost\n"
      scope = headers(date).join('/')
      string_to_sign = "AWS4-HMAC-SHA256\n#{time}\n#{scope}\n#{request_signature}"
      pass = to_hex(hmac(string_to_sign,headers(date).inject("AWS4" + secret_key) { |s,i| hmac(i,s) }))

      endpoint = host
      endpoint += ":#{port}" if port

      "https://#{access_key}:#{time}Z#{pass}@#{endpoint}#{path}"
    end
    module_function :signed_uri

  end
end
