# frozen_string_literal: true

require 'net/http'
require 'ostruct'
require 'celluloid/autostart'
require 'celluloid/pool'
require 'celluloid'
require 'httparty'
require_relative 'helper'
require_relative 'response'
require_relative 'ping_worker'

##
class Ping
  include Logging
  include CsvParser

  attr_reader :pool, :pool_size, :options, :responses

  def initialize(file_path, options = {})
    @mutex     = Mutex.new
    @responses = []
    @options = options
    file_exist?(file_path)
    initialize_csv(file_path, options)
    initialize_pool(options) if options.key?(:parallel)
  end

  def run
    filter(options)
    perform
    print_results
    print_summary
  end

  def initialize_pool(options)
    thread_count = options[:parallel].to_i
    raise ArgumentError, 'error while parsing integer' unless thread_count.is_a? Integer

    @pool_size = /[0-9]/.match(options[:parallel]).to_s.to_i
    logger.debug "pool size: #{@pool_size}"
    @pool = PingWorker.pool(size: @pool_size)
  end

  def perform
    keyword = @options[:filter] if @options.key?(:filter)
    @data.each do |url|
      if !pool.nil?
        @mutex.lock
        @responses << @pool.send_request(url, keyword)
        @mutex.unlock
      else
        send_request(url, keyword)
      end
    end
  end

  def print_results
    @responses.each do |x|
      puts x.to_s
    end
  end

  def print_summary
    succeed = @responses.select(&:success?).count
    failed = @responses.select(&:fail?).count
    errored = @responses.select(&:error?).count
    puts "Total: #{@responses.size}, Success: #{succeed}, Failed: #{failed}, Errored: #{errored}"
  end

  def send_request(uri, keyword = '')
    logger.debug "sending request to #{uri}"
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

    @mutex.lock
    rs.is_err = rs.code.zero? | rs.is_err
    @responses << Response.new(url: uri, code: rs.code, message: rs.message, time: rs.time, err: rs.is_err)
    @mutex.unlock
  end

  def file_exist?(file_path)
    raise ArgumentError, 'file does not exist' unless File.exist?(file_path)
  end
end
