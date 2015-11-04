require 'thread'
require 'ostruct'

class ShellOut
  #
  # It respects ege case when a bunch of lines should be written out
  # however there's a trailing line which shouldn't be messed up!
  #
  class Writer
    attr_reader :id

    def initialize(id)
      @id = id
      @trailing = nil
    end

    def trailing=(value)
      unless value.to_s.empty?
        @trailing = value
      end
    end

    def trailing
      @trailing.to_s.empty? ? nil : @trailing
    end

    def trailing!
      trailing.dup.tap { @trailing = nil }
    end

    # Indicates that a writer hasn't yet flushed its trailing message
    def pending?
      !trailing.nil?
    end
  end

  class << self
    attr_reader :thread, :stopping

    def update_data(id, hash)
      if hash.is_a?(Hash) && !hash.empty?
        userdata[id] = userdata[id].merge(hash)
      else
        {}
      end
    end

    def output=(new_value)
      @output = new_value
    end

    def output
      @output ||= $stdout
    end

    def header_procs
      @header_procs ||= Hash.new
    end

    def add_header_proc(procid, &header_proc)
      header_procs[procid] = header_proc if header_proc
    end

    # Creates ShellOut message
    def message(message, trailing=nil, options={})
      raise ArgumentError, "#message requires options[:id]" unless options[:id]
      OpenStruct.new( id: options[:id],
                      message: message,
                      trailing: trailing,
                      options: options
                    )
    end

    # Enqueue messgage to ShellOut
    def <<(obj)
      if [:id, :message, :trailing].all? {|m| obj.respond_to?(m)}
        enqueue_message(obj)
      else
        raise ArgumentError, "#<< method requires argument responding to :id, :message, :trailing"
      end
    end

    # Flush the output queue
    def flush
      Thread.exclusive do
        while !output_queue.empty? do
          write_message(output_queue.pop)
        end
      end
    end

    # Consume ShellOut output queue
    def run
      @thread = Thread.new do
        while true do
          if thread.status == 'aborting'
            flush
            break
          end
          write_message(output_queue.pop)
        end
      end.run
    end

    private

    # Custom user data, for holding various user information
    def userdata
      @userdata ||= Hash.new({})
    end

    def semaphore
      @semaphore ||= Mutex.new
    end

    # Enqueues a new message obj into the ShellOut queue
    def enqueue_message(obj)
      output_queue << obj
    end

    # Write trailing message returns a new message with
    # a clean out continuation.
    def write_trailing_message(obj)
      if writer_for(obj).pending?
        continuation, new_message = obj.message.split("\n", 2)
        trailing = writer_for(obj).trailing!
        output << "%s%s\n" % [trailing, continuation]
        new_message
      else
        obj.message
      end
    end

    # Atomic message output, we synchronize parallel threads
    def write_message(obj)
      semaphore.synchronize do
        new_message = write_trailing_message(obj)
        if new_message
          obj = obj.dup
          obj.message = new_message.chomp
          inject_headers!(obj)
          writer_for(obj).trailing = obj.trailing
          output << obj.message + "\n"
          output.flush
        end
      end
    end

    # Invoke header proc over a message object.
    def inject_headers!(obj)
      procid = obj[:options][:header]
      if procid && header_proc = header_procs[procid]
        data = userdata[obj.id]
        obj.trailing, trailing = nil, obj.trailing
        obj.message = header_proc.call(obj.message, data)
        obj.trailing = header_proc.call(trailing, data) if !trailing.to_s.empty?
      end
    end

    def output_queue
      @output_queue ||= Queue.new
    end

    def writer_for(obj)
      writers[obj.id]
    end

    def writers
      @writers ||= Hash.new {|hash, id| hash[id] = Writer.new(id)}
    end
  end
end

# We have to run and finalize threaded output dispatcher.
# Otherwise we won't see any output :)
ShellOut.run
