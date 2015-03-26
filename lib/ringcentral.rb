require 'rest_client'

module RingCentral
  
  URL = 'https://service.ringcentral.com'
  
  class Fax
    
    PATH = 'faxapi.asp'
    URL = [RingCentral::URL, PATH].join('/')
    
    STATUS_CODES = {
      0 => 'Successful',
      1 => 'Authorization failed',
      2 => 'Faxing is prohibited for the account',
      3 => 'No recipients specified',
      4 => 'No fax data specified',
      5 => 'Generic error'
    }
    
    def self.send(username, password, extension, recipient, attachment, cover_page = 'None', cover_page_text = nil, resolution = nil, send_time = nil)
      
      params = {
        :attachment => attachment,
        :recipient => recipient,
        :coverpage => cover_page,
        :coverpagetext => cover_page_text,
        :resolution => resolution,
        :sendtime => send_time
      }
      
      username_with_extension = [username, extension].compact.join('*')
      
      response = RestClient.post(URL, params.merge(RingCentral.credentials_hash(username_with_extension, password)))
      
      status_code = String.new(response.body).to_i # RestClient::Response casting to int behaves strangely
      
      return STATUS_CODES[status_code]
    end
    
  end
  
  class Phone
    
    PATH = 'ringout.asp'
    URL = [RingCentral::URL, PATH].join('/')
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
    
    
    def self.list(username, password, extension)
      
      params = { :cmd => :list }
      response = RestClient.get(URL, params: params.merge(RingCentral.credentials_hash(username, password, extension)))
      body = response.body
      
      if body[0..1] == SuccessResponse # sucessful responses start with "OK "
        data = body[3..-1]
        return Hash[*data.split(';')].invert
      else
        raise "RingCentral response: #{body}"
      end
    end
    
    
    def self.call(username, password, extension, to, from, caller_id, prompt = 1)
      
      params = {
        :cmd => :call,
        :to => to,
        :from => from,
        :clid => caller_id,
        :prompt => prompt
      }
      response = RestClient.post(URL, params.merge(RingCentral.credentials_hash(username, password, extension)))
      body = response.body
      
      if body[0..1] == SuccessResponse # sucessful responses start with "OK "
        session_id, ws = body[3..-1].split(' ')
        return { :session_id => session_id, :ws => ws }
      else
        raise "RingCentral response: #{body}"
      end
    end
    
    
    # Notes:
    #  - WS param doesn't seem to do anything or even be required
    #  - API always gives the "completed call" response regardless of whether the session ID is valid
    #  - while call is running (and for a few seconds after it is disconnected), status string with both callback 
    #    and destination number are given, with statuses for both; after that, only the session ID is given
    def self.status(session_id, ws = nil)
      
      params = {
        :cmd => :status,
        :sessionid => session_id,
        :ws => ws
      }
      response = RestClient.post(URL, params)
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
    end
    
    
    def self.cancel(session_id, ws = nil)
      
      params = {
        :cmd => :cancel,
        :sessionid => session_id,
        :ws => ws
      }
      response = RestClient.post(URL, params)
      body = response.body
      
      if body[0..1] == SuccessResponse # sucessful responses start with "OK "
        session_id = body[3..-1]
        return { :session_id => session_id }
      else
        raise "RingCentral response: #{body}"
      end
    end
  end
  
  
  private
  
  def self.credentials_hash(username, password, extension = nil)
    {
      :username => username,
      :password => password,
      :ext => extension
    }
  end
  
end
