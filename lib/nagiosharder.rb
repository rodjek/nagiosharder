require 'restclient'
require 'nokogiri'
require 'activesupport'
require 'httparty'

class NagiosHarder
  class Site
    attr_accessor :nagios_url, :user, :password, :default_options, :default_cookies
    include HTTParty::ClassMethods

    def initialize(nagios_url, user, password)
      @nagios_url = nagios_url.gsub(/\/$/, '')
      @user = user
      @password = password
      @default_options = {}
      @default_cookies = {}
      basic_auth(@user, @password) if @user && @password
    end

    def status_url
      "#{nagios_url}/status.cgi"
    end

    def cmd_url
      "#{nagios_url}/cmd.cgi"
    end

    def schedule_service_check(host)
      response = post(cmd_url, :body => {
                                         :start_time => Time.now,
                                         :host => host,
                                         :force_check => true,
                                         :cmd_typ => 92,
                                         :cmd_mod => 2
                                       })

      response.code == 200 && response.body =~ /successful/
    end

    def host_status(host)
      host_status_url = "#{status_url}?host=#{host}"
      response =  get(host_status_url)

      raise "wtf #{host_status_url}? #{response.code}" unless response.code == 200
      doc = Nokogiri::HTML(response)
      rows = doc.css('table.status > tr > td').to_a.in_groups_of(7)

      rows.inject({}) do |services, row|
        service = row[1].inner_text.gsub(/\n/, '')
        status = row[2].inner_html
        last_check = row[3].inner_html
        duration = row[4].inner_html
        started_at = if match_data = duration.match(/^\s*(\d+)d\s+(\d+)h\s+(\d+)m\s+(\d+)s\s*$/)
                       (
                         match_data[1].to_i.days +
                         match_data[2].to_i.hours +
                         match_data[3].to_i.minutes +
                         match_data[4].to_i.seconds
                       ).ago

                     end
        attempts = row[5].inner_html
        status_info = row[6].inner_html.gsub('&nbsp;', '')

        services[service] = {
          :status => status,
          :last_check => last_check,
          :duration => duration,
          :attempts => attempts,
          :started_at => started_at,
          :extended_info => status_info
        }

        services
      end
    end

  end


end
