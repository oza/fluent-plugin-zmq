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
    require 'zmq'
    require 'msgpack'
    
    z = ZMQ::Context.new
    s = z.socket(ZMQ::DOWNSTREAM)
    s.connect("tcp://127.0.0.1:4444")
    tag = "debug.test"
    # echo '{"json":"message"}' | fluent-cat debug.test
    array = ["key" => "value"]
    
    def write_impl(s, tag, array)
      begin
        s.send([tag, Time.now.to_s, array].to_msgpack)
      rescue
        $stderr.puts "write failed: #{$!}"
        s.close
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

