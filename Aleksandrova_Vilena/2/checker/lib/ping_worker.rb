# frozen_string_literal: true

require_relative 'response'
require 'net/http'
require 'celluloid/autostart'
require 'celluloid/pool'
require 'celluloid'
require 'httparty'
require 'benchmark'

##
class PingWorker
  include Logging
  include Celluloid

  def send_request(uri, keyword = '')
    rs = nil
    begin
      rs = http_req(uri, keyword)
      return if keyword && rs.keyword.nil?
    rescue StandardError => e
      rs = Response.new(uri: uri, is_err: true, msg: e.to_s)
    end
    rs
  end

  private

  def http_req(uri, keyword)
    resp = {}
    time = Benchmark.realtime do
      resp = HTTParty.get("http://#{uri}", timeout: 3)
    end
    is_keyword = true if keyword && resp.body.include?(keyword)
    Response.new(uri: uri,
                 code: resp.code,
                 msg: resp.message,
                 time: (time.to_f * 1000.0).ceil(1),
                 is_keyword: is_keyword, is_err: false)
  end
end
