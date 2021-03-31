require 'thread'
require './rake/shellout'

module SSHKit
  module Formatter
    class ShellOut < Abstract
      HEADERS_LIST = [:label, :uuid, :debug].freeze
      HEADERS_COLORS = Hash[ HEADERS_LIST.zip([
        :cyan, :magenta, :light_black
      ])].freeze

      Dispatcher = ::ShellOut
      attr_accessor :header_spacing, :command_spacing

      def initialize(output)
        super
        @header_spacing = 2
        @command_spacing = 4
        Dispatcher.add_header_proc(:info) do |lines, data|
          spaces = header_spacing
          inject_headers(data[:command], lines, spaces)
        end
        Dispatcher.add_header_proc(:command) do |lines, data|
          spaces = header_spacing + command_spacing
          inject_headers(data[:command], lines, spaces)
        end
      end

      def log_command_data(command, stream_type, stream_data)
        if [:stdout, :stderr].none? {|t| t == stream_type}
          raise "Unrecognised stream_type #{stream_type}, expected :stdout or :stderr"
        end
        unless command.finished?
          message, _, trailing = stream_data.rpartition("\n")
          write_command(command, message, trailing)
        end
      end

      def log_command_start(command)
        if command.options[:show_start_message]
          host_prefix = command.host.user ? "as #{colorize(command.host.user, :blue)}@" : 'on '
          message = "Running #{colorize(command, :yellow, :bold)} #{host_prefix}#{colorize(command.host, :blue)}"
          write_message(command, message)
        end
      end

      def log_command_exit(command)
        if command.options[:show_exit_status]
          runtime = sprintf('%5.3f seconds', command.runtime)
          successful_or_failed =  command.failure? ? colorize('failed', :red, :bold) : colorize('successful', :green, :bold)
          message = "Finished in #{runtime} with exit status #{command.exit_status} (#{successful_or_failed})."
          write_message(command, message)
        end
      end

      def write(_obj)
        # Nothing, nothing to do
      end

      private

      def logger(verbosity)
        verbosity.is_a?(Integer) ? verbosity : Logger.const_get(verbosity.upcase)
      end

      def write_message(command, message, trailing=nil)
        Dispatcher.update_data(command.uuid, {command: command})
        Dispatcher << Dispatcher.message(message, trailing,
                                          id: command.uuid,
                                          header: :info)
      end

      def write_command(command, message, trailing=nil)
        Dispatcher.update_data(command.uuid, {command: command})
        Dispatcher << Dispatcher.message(message, trailing,
                                          id: command.uuid,
                                          header: :command)
      end

      # Inject headers into each line of text
      def inject_headers(command, lines, spaces=2)
        headers = command_headers(command)
        spacing = headers.empty? ? 0 : spaces
        fullheader = ("%s%#{spacing}s") % [headers, '']
        lines.gsub(/^/m, fullheader)
      end

      def command_headers(command)
        ShellOut::HEADERS_LIST.inject('') do |result, k|
          color = command.failure? ? [:red, :bold] : Array(ShellOut::HEADERS_COLORS[k])
          header = send(:"header_#{k}", command) if respond_to?(:"header_#{k}", true)
          header ? result << '[%s] [%s]' % [colorize(header, *color), Time.at(Time.new).utc.strftime("%H:%M:%S")] : result
        end
      end

      def header_label(command)
        command.options[:label] and command.options[:label].to_s
      end

      def header_uuid(command)
        command.options[:show_uuid] and command.uuid and command.uuid.to_s
      end

      def header_debug(command)
        if logger(command.verbosity || Remote.output_verbosity) == Logger::DEBUG
          'DEBUG'
        end
      end

    end
  end
end
