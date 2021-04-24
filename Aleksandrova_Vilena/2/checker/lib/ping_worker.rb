# frozen_string_literal: true
require_relative 'response'
require 'net/http'
require 'celluloid/autostart'
require 'celluloid/pool'
require 'celluloid'
require 'httparty'

##
class PingWorker
  include Logging
  include Celluloid
  def send_request(uri, keyword = '')
    rs = OpenStruct.new({ code: 0, message: '', time: 0, is_err: false })
    begin
      time_start = Time.now
      resp = HTTParty.get("http://#{uri}", { timeout: 3 })
      time_end = Time.now
      return if keyword && resp.body.include?(keyword) == false

      rs.time = ((time_end - time_start).to_f * 1000.0).ceil(1)
      rs.code = resp.code
      rs.message = resp.message
    rescue StandardError => e
      rs.is_error = true
      rs.message = e.to_s
    end
    Response.new(url: uri, code: rs.code, message: rs.message, time: rs.time, err: rs.is_err)
  end
end
