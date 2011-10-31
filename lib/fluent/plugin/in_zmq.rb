#!/usr/bin/env ruby

require "fluent-plugin-zmq/version"
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


module Fluent

class ZMQInput < Input
  Plugin.register_input('zmq', self)

  config_param :port,            :integer, :default => 4010
  config_param :bind,            :string,  :default => '0.0.0.0'
  config_param :body_size_limit, :size,    :default => 32*1024*1024  # TODO default
  #config_param :server_type,     :string,  :default => 'nonblocking'

  def initialize
    require 'zmq'
    super
  end

  def configure(conf)
    super
  end

  def start
    Signal.trap(:INT){
      $log.error "SIGINT occured. shutdown..."
      @server.close
      exit(0)
    }

    $log.debug "listening http on #{@bind}:#{@port}"
    @zmq = ZMQ::Context.new
    @server = @zmq.socket(ZMQ::UPSTREAM)
    @server.bind("tcp://" + @bind + ":" + @port.to_s)
    @thread = Thread.new(&method(:run))
  end

  def run
    begin
      while true
        ret = ZMQ::select([@server])
        ret[0].each do |sock|
          msg = sock.recv
          on_message(MessagePack.unpack(msg))
        end
      end
    rescue
      $log.error "unexpected error", :error=>$!.to_s
      $log.error_backtrace
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
    time = msg[1]
    time = Engine.now if time == 0
    record = msg[2]

    # for debugging
    #p tag
    #p time
    #p record

    Engine.emit(tag, time, record)

    # TODO : support other formats
    #if entries.class == String
    #  # PackedForward
    #  es = MessagePackEventStream.new(entries, @cached_unpacker)
    #  Engine.emit_stream(tag, es)

    #elsif entries.class == Array
    #  # Forward
    #  es = MultiEventStream.new
    #  entries.each {|e|
    #    time = e[0].to_i
    #    time = (now ||= Engine.now) if time == 0
    #    record = e[1]
    #    es.add(time, record)
    #  }
    #  Engine.emit_stream(tag, es)

    #else
    #  # Message
    #  time = msg[1]
    #  time = Engine.now if time == 0
    #  record = msg[2]
    #  Engine.emit(tag, time, record)
    #end
  end

  def shutdown
    @server.close
    #@thread.join # TODO
  end
end

end
