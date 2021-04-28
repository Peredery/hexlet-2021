# frozen_string_literal: true

require 'net/http'
require 'ostruct'
require 'celluloid/autostart'
require 'celluloid/pool'
require 'celluloid'
require 'httparty'
require_relative 'logging'
require_relative 'csv_parser'
require_relative 'response'
require_relative 'ping_worker'

# Ping
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
    @pool = initialize_pool(options)
  end

  def run
    filter(options)
    perform
    print_results
    print_summary
  end

  def print_results
    @responses.each do |x|
      puts x.to_s
    end
  end

  def print_summary
    success = @responses.count(&:success?)
    failed = @responses.count(&:fail?)
    errored = @responses.count(&:error?)
    puts "Total: #{@responses.size}, Success: #{success}, Failed: #{failed}, Errored: #{errored}"
  end

  def file_exist?(file_path)
    raise ArgumentError, 'file does not exist' unless File.exist?(file_path)
  end

  private

  def initialize_pool(options)
    return PingWorker.pool(size: 1) if options.key?(:parallel) == false

    thread_count = options[:parallel].to_i
    raise ArgumentError, 'argument error' unless thread_count.is_a? Integer

    @pool_size = /[0-9]/.match(options[:parallel]).to_s.to_i
    logger.debug "pool size: #{@pool_size}"
    PingWorker.pool(size: @pool_size)
  end

  def perform
    keyword = @options[:filter] if @options.key?(:filter)
    @data.each do |url|
      resp = @pool.send_request(url, keyword)
      @mutex.lock
      @responses << resp unless resp.nil?
      @mutex.unlock
    end
  end
end
