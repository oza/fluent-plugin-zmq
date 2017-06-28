#!/usr/bin/env ruby

#
# Fluent
#
# Copyright (C) 2011 OZAWA Tsuyoshi
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

require 'fluent/input'

module Fluent

class ZMQInput < Input
  Fluent::Plugin.register_input('zmq', self)

  config_param :port,            :integer, :default => 4010
  config_param :bind,            :string,  :default => '0.0.0.0'
  config_param :body_size_limit, :size,    :default => 32*1024*1024  # TODO default
  #config_param :server_type,     :string,  :default => 'nonblocking'

  def initialize
    require 'cztop'
    super
  end

  def configure(conf)
    super
    @unpacker = Fluent::Engine.msgpack_factory.unpacker
  end

  def start
    super
    $log.debug "listening http on #{@bind}:#{@port}"
    @running = true
    @socket = CZTop::Socket::PULL.new("tcp://" + @bind + ":" + @port.to_s)
    @thread = Thread.new(&method(:run))
  end

  def shutdown
    @running = false
    @thread.kill
    @socket.close
    super
  end

  def run
    begin
      while @running
        message = @socket.receive rescue nil
        message.to_a.each do |msg|
          @unpacker.feed(msg)
          on_message(@unpacker.read)
        end
      end
    rescue
      log.error "unexpected error", :error=>$!.to_s
      log.error_backtrace
    end
  end

  # message Entry {
  #   1: long time
  #   2: object record
  # }
  #
  # message Forward {
  #   1: string tag
  #   2: list<Entry> entries
  # }
  #
  # message PackedForward {
  #   1: string tag
  #   2: raw entries  # msgpack stream of Entry
  # }
  #
  # message Message {
  #   1: string tag
  #   2: long? time
  #   3: object record
  # }
  def on_message(msg)
    # TODO format error
    tag = msg[0].to_s
    entries = msg[1]

    if entries.class == String
      # PackedForward
      es = MessagePackEventStream.new(entries)
      router.emit_stream(tag, es)

    elsif entries.class == Array
      # Forward
      es = MultiEventStream.new
      entries.each {|e|
        time = e[0].to_i
        time = (now ||= Engine.now) if time == 0
        record = e[1]
        es.add(time, record)
      }
      router.emit_stream(tag, es)
    else
      # Message
      time = msg[1]
      time = Engine.now if time == 0
      record = msg[2]
      router.emit(tag, time, record)
    end
  end
end

end
