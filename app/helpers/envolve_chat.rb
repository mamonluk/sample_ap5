require 'openssl'
require 'base64'

module EnvolveChat
  
  # Envolve API module to create signed commands and javascript tags to interact
  # with the Envolve chat service.
  
  # This is free software intended for integrating your custom ruby
  # software with Envolve's website chat software. You may do with this 
  # software as you wish.
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
  # Modified from an original plugin by Lail Brown <http://github.com/lailbrown>
  
  ENVOLVE_API_VERSION = '0.3'
  ENVOLVE_JS_ROOT = 'd.envolve.com/env.nocache.js'
  
  class ChatRenderer

    def self.get_html(envolve_api_key, args = {} )
      # Returns the javascript tags necessary to use the Envolve API login mechanism.
      # envolve_api_key -- your site's Envolve API key as a string
	  # args -- A hash of the following fields:
      #		first_name -- required string for the user's first name.
      #		last_name -- optional string for the user's last name.
      #		pic -- optional string of the absolute URL to the user's avatar.
      #		is_admin -- optional boolean for the user's admin status.
	  #		profHTML -- optional String for the HTML to be inserted into a user's profile rollover
      #
      # If first_name is not passed in, the user will be anonymous.
      #
      # To use in a Rails app, make sure you have the hmac-sha1 gem and add this module to your /lib folder. 
      # Then call EnvolveChat::ChatRenderer.get_html 
      # from a view or helper with the appropriate keywords specified. The function will
      # return javascript that you can use in your page's HTML.

      # To generate the HTML to insert in your page, call this in a view or helper
      #   EnvolveChat::ChatRenderer.get_html("123-abcdefghijklmnopqrs", 
      #     :first_name => user.first_name,
      #     :last_name => user.last_name,
      #     :pic => user.avatar(:itty_bitty), 
	  #     :is_admin => user.admin, 
      #     :profile_html => user.profile_html
      #   )
      
      # This will produce javascript similar to:

	  #		<!-- Envolve Chat -->
      #		<script type="text/javascript">
      #		var envoSn=123;
	  #     env_commandString="{ command string }";
      #		var envProtoType = (("https:" == document.location.protocol) ? "https://" : "http://");
      #		document.write(unescape("%3Cscript src='" + envProtoType + "d.envolve.com/env.nocache.js' type='text/javascript'%3E%3C/script%3E"));
      #		</script>

      args = {
        :first_name => nil,
        :last_name => nil,
        :pic => nil,
        :is_admin => false,
		:profile_html => nil,
      }.merge(args)

      first_name = args.delete(:first_name)

      api_key = EnvolveChat::EnvolveAPIKey.new(envolve_api_key)
      if first_name
		return get_html_for_command(api_key,
               get_login_command(api_key.full_key, first_name, args))
      else
        return get_html_for_command(api_key, get_logout_command(api_key.full_key))
      end                              
    end
  
    def self.get_login_command(envolve_api_key,first_name, args = {})
      # Returns the hashed login command string for use in the javascript call
      # to the Envolve API.
    
      # Keyword argument:
      # envolve_api_key -- your site's Envolve API key as a string
	  # args -- A hash of the following arguments:
      #		first_name -- required string for the user's first name.
      #		last_name -- optional string for the user's last name.
      #		pic -- optional string of the absolute URL to the user's avatar.
      #		is_admin -- optional boolean for the user's admin status.
	  #		profHTML -- optional String for the HTML to be inserted into a user's profile rollover
    
      api_key = EnvolveChat::EnvolveAPIKey.new(envolve_api_key)
      raise EnvolveChat::EnvolveAPIError.new "You must provide at least a first name. If you are providing a username, use it for the first name." unless first_name
 
      command = [
        "v=#{ENVOLVE_API_VERSION}",
        "c=login",
        "fn=#{encode_to_spec first_name}"
      ]
      command << "ln=#{encode_to_spec args[:last_name]}" if args[:last_name]
      command << "pic=#{encode_to_spec args[:pic]}" if args[:pic]
      command << "prof=#{encode_to_spec args[:profile_html]}" if args[:profile_html]
      command << "admin=#{args[:is_admin] ? 't' : 'f' }"
    
      return wrap_command(api_key, command.join(","))
    end
    
    def self.get_logout_command(envolve_api_key)
      # Returns the hashed logout command string for use in the javascript call to the Envolve API.

      # Keyword argument:
      # envolve_api_key -- your site's Envolve API key as a string

      api_key = EnvolveChat::EnvolveAPIKey.new(envolve_api_key)
      return wrap_command(api_key, "v=#{ENVOLVE_API_VERSION},c=logout")
    end
    
    private
    
    def self.encode_to_spec(str)
      # Returns a base64-encoded string based on the Envolve specifications.
      Base64.encode64(str).gsub("+", "-").gsub("/", "_").chomp.gsub(/\n/,'')
    end
    
    def self.wrap_command(api_key,command)
      # Returns the hashed command string to perform calls to the API.
    
      # Keyword arguments:
      # api_key -- EnvolveAPIKey object
      # command -- plaintext command string
    
      k = api_key.secret_key
      t = Time.now.to_i * 1000 # milliseconds since epoch
	  digest  = OpenSSL::Digest::Digest.new('sha1')
	  h = OpenSSL::HMAC.hexdigest(digest, k, "#{t};#{command}")
    
      return "#{h};#{t};#{command}"
    end
    
    def self.get_html_for_command(api_key, command = nil)
    
      # Returns the javascript tags for a given hashed command.

      # Keyword arguments:
      # api_key -- EnvolveAPIKey object
      # command -- Hashed command string for which to return the javascript.
	  
	  js = ['<!-- Envolve Chat -->',
            '<script type="text/javascript">',
            "var envoSn=#{api_key.site_id};"]
      js << "env_commandString='#{command}';" if command
	  js << 'var envProtoType = (("https:" == document.location.protocol) ? "https://" : "http://");'
      js << "document.write(unescape(\"%3Cscript src='\" + envProtoType + \"#{ENVOLVE_JS_ROOT}' type='text/javascript'%3E%3C/script%3E\"));"
      js << "</script>"
      return js.join "\n"
    end
  
  end # close class
  
  class EnvolveAPIError < StandardError
  end

  class EnvolveAPIKey
    attr_accessor :site_id
    attr_accessor :secret_key
    attr_accessor :full_key
    
    def initialize(api_key)
      # Handles encapsulation and validation of the Envolve API key.

      # Keyword arguments:
      # api_key -- optional string argument that defaults to ENVOLVE_API_KEY.
      begin
        api_key_pieces = api_key.strip.split('-')
        raise EnvolveChat::EnvolveAPIError.new "Invalid or missing Envolve API Key." unless ( api_key_pieces.size == 2 and api_key_pieces[0].length > 0 and api_key_pieces[1].length > 0 )
      rescue
        raise EnvolveChat::EnvolveAPIError.new "Invalid or missing Envolve API Key."
      end

      self.site_id = api_key_pieces[0]
      self.secret_key = api_key_pieces[1]
      self.full_key = "#{self.site_id}-#{self.secret_key}"
    end
  end
  
end