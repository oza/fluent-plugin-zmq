Zeromq plugin for [Fluentd](http://fluentd.org)
=============
fluent-plugin-zmq provides an adaptor between fluentd and zeromq.

# Getting Started
Setup the ZeroMQ input:

~~~~~
    <source>
      type zmq
      port 4444
    </source>
~~~~~

Run a sample code.

~~~~~
    #!/usr/bin/env ruby
    require 'cztop'
    require 'msgpack'

    s = CZTop::Socket::PUSH.new("tcp://127.0.0.1:4010")
    tag = "debug.test"
    # echo '{"json":"message"}' | fluent-cat debug.test
    array = ["key" => "value"]

    def write_impl(s, tag, array)
      msg = ''
      begin
        s << [tag, Time.now.to_i, array].to_msgpack
      rescue
        $stderr.puts "write failed: #{$!}"
      ensure
        return false
      end

      return true
    end

    write_impl(s, tag, array)
~~~~~

That's done.
Happy logging with zeromq and fluetnd! :)

# TODO
- ZeroMQ output
- ZeroMQ forwarding
- JSON support
