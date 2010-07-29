require 'uri'
require 'net/https'

module RingCentral
  
  Url = 'https://service.ringcentral.com'
  
  class Fax
    
    Path = '/faxapi.asp'
    
  end
  
  class Phone
    
    Path = '/ringout.asp'
    SuccessResponse = 'OK'
    
    STATUS_CODES = {
      0 => 'Success',          # picked up, line open (gets set for the callback number before the destination)
      1 => 'In Progress',      # ringing (or waiting to be rung if it's the destination number)
      2 => 'Busy',             # appears in the "general call status" field after call has completed
      3 => 'No Answer',
      4 => 'Rejected',         # party hung up, line closed
      5 => 'Generic Error',
      6 => 'Finished',         # other party hung up, line closed
      7 => 'International calls disabled',
      8 => 'Destination number prohibited'
    }
    
    def self.list(username, extension, password)
      response = connection.post(Path, command_query_string('list', username, extension, password))
      
      if response.is_a? Net::HTTPSuccess
        body = response.body
        if body[0..1] == SuccessResponse # sucessful responses start with "OK "
          data = body[3..-1]
          return Hash[*data.split(';')].invert
        else
          raise "RingCentral response: #{body}"
        end
      else
        response.error!
      end
    end
    
    def self.call(username, extension, password, to, from, caller_id, prompt = 1)
      params = "&to=#{to}&from=#{from}&clid=#{caller_id}&prompt=#{prompt}"
      response = connection.post(Path, command_query_string('call', username, extension, password) + params)
      
      if response.is_a? Net::HTTPSuccess
        body = response.body
        if body[0..1] == SuccessResponse # sucessful responses start with "OK "
          session_id, ws = body[3..-1].split(' ')
          return { :session_id => session_id, :ws => ws }
        else
          raise "RingCentral response: #{body}"
        end
      else
        response.error!
      end
    end
    
    # Notes:
    #  - WS param doesn't seem to do anything or even be required
    #  - API always gives the "completed call" response regardless of whether the session ID is valid
    #  - while call is running (and for a few seconds after it is disconnected), status string with both callback 
    #    and destination number are given, with statuses for both; after that, only the session ID is given
    def self.status(username, extension, password, session_id, ws = nil)
      params = "&sessionid=#{session_id}&ws=#{ws}"
      response = connection.post(Path, command_query_string('status', username, extension, password) + params)
      
      if response.is_a? Net::HTTPSuccess
        body = response.body
        if body[0..1] == SuccessResponse # sucessful responses start with "OK "
          session_id, statuses = body[3..-1].split(' ')
          if statuses
            statuses = statuses.split(';')
            return {
              :general     => STATUS_CODES[statuses[0].to_i],
              :destination => STATUS_CODES[statuses[2].to_i],
              :callback    => STATUS_CODES[statuses[4].to_i]
            }
          else
            return {
              :general     => "Call Completed",
              :destination => "Call Completed",
              :callback    => "Call Completed"
            }
          end
        else
          raise "RingCentral response: #{body}"
        end
      else
        response.error!
      end
    end
    
    def self.cancel(username, extension, password, session_id, ws = nil)
      params = "&sessionid=#{session_id}&ws=#{ws}"
      response = connection.post(Path, command_query_string('cancel', username, extension, password) + params)
      
      if response.is_a? Net::HTTPSuccess
        body = response.body
        if body[0..1] == SuccessResponse # sucessful responses start with "OK "
          session_id = body[3..-1]
          return { :session_id => session_id }
        else
          raise "RingCentral response: #{body}"
        end
      else
        response.error!
      end
    end
    
    
    private
    
    def self.connection
      uri = URI.parse(Url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      return http
    end
    
    def self.command_query_string(command, username, extension, password)
      "cmd=#{command}&username=#{username}&ext=#{extension}&password=#{password}"
    end
  end
  
end