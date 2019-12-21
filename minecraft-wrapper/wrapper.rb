require 'zlib'
require 'open3'
require 'pty'
require 'io/console'
require 'socket'
require 'fcntl'
require 'strscan'
require 'logger'

$TOTAL_COMMANDS = 0
$TOTAL_REPLYS = 0

USE_POPEN3 = true
FIXNUM_MAX = (2**(0.size * 8 -2) -1)

READ_CHUNKS = 1024
READ_CHUNKS_REMOTE = 1024 # 59 ... 512 * 32
COMMANDS_PER_MOD = 128

#READ_CHUNKS = 64 #512 * 32
#READ_CHUNKS_REMOTE = 64 # # 512 * 32
#COMMANDS_PER_MOD = 2

CLIENTS_DEFAULT_ASYNC = false

class Wrapper
  class Client < Struct.new(:uid, :authentic, :async, :left_over_command, :broadcast_scanner, :gzip_pump, :gzip_sink)
  end

  attr_accessor :running, :uid,
                :stdin, :stdout, :stderr,
                :server_io, :clients,
                :minecraft_stdin, :minecraft_stdout, :minecraft_stderr, :minecraft_thread,
                :prefetched_broadcast,
                :command, :options,
                :input_waiting_to_be_written_to_minecraft,
                :full_commands_waiting_to_be_written_to_minecraft,
                :logger,
                :time_since_last_stat,
                :count_since_last,
                :time_since_last_process,
                :confirmed_since_last

  def initialize(logger, descriptors, argv)
    @count = 0

    self.time_since_last_process = self.time_since_last_stat = Time.now
    self.count_since_last = 0
    self.confirmed_since_last = 0

    self.logger = logger
    self.full_commands_waiting_to_be_written_to_minecraft = []
    self.install_trap

    self.running = true
    self.uid = 0
    self.clients = Hash.new

    #self.stdin = $stdin
    #self.stdout = $stdout
    #self.stderr = $stderr

    self.command = argv[0]
    self.options = argv[1..-1]

    if descriptors.empty?
      create_descriptors
    else
      load_descriptors(descriptors)
    end

    self.minecraft_stdin.autoclose = false
    self.minecraft_stdout.autoclose = false
    self.prefetched_broadcast = ""
    self.input_waiting_to_be_written_to_minecraft = {}

    #install_client(self.stdin, true)
    #self.logger.crit("starting")
    #self.logger.level = :debug
    puts "starting"
  end

  def install_trap
    Signal.trap("INT") do
      write_minecraft_command("save-all")
      write_minecraft_command("stop")
    end
  end

  def create_server_io
    self.server_io = TCPServer.new(ENV["MAVENCRAFT_WRAPPER_PORT"] || 25566)
  end

  def create_minecraft_io
    if self.command
      if USE_POPEN3
        self.minecraft_stdin, self.minecraft_stdout, self.minecraft_stderr, self.minecraft_thread = Open3.popen3(self.command, *self.options)
      else
        combined = [self.command, *self.options]
        self.minecraft_stdout, self.minecraft_stdin, self.minecraft_thread = PTY.spawn(*combined)
        self.minecraft_stdin.echo = false
        self.minecraft_stderr = nil
      end
    else
      raise "command required for wrapper"
    end
  end

  def create_descriptors
    create_server_io
    create_minecraft_io
  end

  def load_descriptors(descriptors)
    self.minecraft_stdin = descriptors.shift
    raise unless self.minecraft_stdin
    self.minecraft_stdout = descriptors.shift
    raise unless self.minecraft_stdout
    self.minecraft_stderr = descriptors.shift
    raise unless self.minecraft_stderr

    self.server_io = descriptors.shift
    raise unless self.server_io

    while client = descriptors.shift
      install_client(client, true)
    end
  end

  def descriptors
    [self.minecraft_stdin, self.minecraft_stdout, self.minecraft_stderr, self.server_io] + (self.clients.keys)
  end

  def selectable_descriptors
    [self.minecraft_stdout, self.server_io] + self.clients.keys
  end

  def writable_descriptors
    [self.minecraft_stdin] + (self.clients.keys)
  end

  def accept_server_io_connection
    puts [:connected_client]
    install_client(self.server_io.accept_nonblock)
  end

  def install_client(client_io, authentic = nil)
    self.clients[client_io] = Client.new(self.uid, authentic, CLIENTS_DEFAULT_ASYNC)
    self.clients[client_io].broadcast_scanner = StringScanner.new("")
    self.uid += 1
  end

  def handle_minecraft_stdout
    self.running = (!self.minecraft_stdin.closed?) # && !self.minecraft_stdout.eof?)
    if self.running
      broadcast_bytes = nil

      begin
        broadcast_bytes = self.minecraft_stdout.read_nonblock(READ_CHUNKS)
      rescue IO::EAGAINWaitReadable, Errno::EAGAIN => e
        puts "ok #{e}"
      rescue Errno::ECONNRESET, Errno::EPIPE, IOError => e
	      puts self.minecraft_stderr.read
        puts "wtf #{e}"
        exit 1
      end

      if broadcast_bytes
        $TOTAL_REPLYS += broadcast_bytes.count("\n")

        broadcast_bytes.gsub!("\b", "")
        broadcast_bytes.squeeze!(" ")

        if broadcast_bytes.length == 0
          return
        else
          #puts "OUT: #{broadcast_bytes.inspect}"

          #TODO: keep on global scanner?
          #TODO: yes
          #puts broadcast_bytes
          self.clients.each do |io, client|
            client.broadcast_scanner << broadcast_bytes if client.authentic
          end
        end
      end
    end
  end

  def handle_descriptors_requiring_reading(ready_for_read)
    ready_for_read.each do |readable_io|
      case readable_io
        when self.minecraft_stdout # minecraft has emitted output / command results
          handle_minecraft_stdout
        when self.server_io # client is connecting over unix socket
          accept_server_io_connection
      else # some input from the api server from a client script
        begin
          client_input_bytes = readable_io.read_nonblock(READ_CHUNKS_REMOTE)
          enqueue_input_for_minecraft(readable_io, client_input_bytes)
        rescue Errno::ECONNRESET, Errno::EPIPE, IOError => e
          close_client(readable_io, e)
        end
      end
    end
  end

  def handle_descriptors_requiring_writing(ready_for_write)
    ready_for_write.each do |writable_io|
      case writable_io
        when self.minecraft_stdin # minecraft is ready for more input
          handle_minecraft_stdin
      else # broadcast any output from minecraft that has occured since last time
        broadcast_latest_stdout(writable_io)
      end
    end
  end

  def handle_minecraft_stdin
    self.input_waiting_to_be_written_to_minecraft.each do |io, byte_scanner|
      client = self.clients[io]
      count_per_client = 0
      while client && has_eol = byte_scanner.check_until(/\n/)
        full_command_line = byte_scanner.scan_until(/\n/)

        stripped_command = full_command_line.strip

        if client.authentic
          if stripped_command.length > 0
            count_per_client += 1

            if stripped_command == "exit"
              close_client(io, Exception.new("exit"))
            elsif stripped_command == "async" #NOTE: this doesnt do much now
              #client.async = !client.async
            else
              if stripped_command == "save-all"
                self.full_commands_waiting_to_be_written_to_minecraft.unshift(full_command_line)
                close_client(io, Exception.new("saved: #{full_command_line}")) unless client.async
              else
                self.full_commands_waiting_to_be_written_to_minecraft.unshift(stripped_command)
                #self.full_commands_waiting_to_be_written_to_minecraft << stripped_command
                #break
              end
            end
          end
        else
          client.authentic = stripped_command == "authentic"
          unless client.authentic
            close_client(io, Exception.new("not authentic: #{full_command_line}"))
          end
        end
      end
    end

    commands_run = 0
    start = Time.now

    total_delta = 0

    ((full_command_line = self.full_commands_waiting_to_be_written_to_minecraft.shift(COMMANDS_PER_MOD)) && (full_command_line.length > 0))
      commands_this_tick = full_command_line.length

      full_command_line.each do |fcl|
        blob = fcl.strip

        write_minecraft_command(blob)
      end

      $TOTAL_COMMANDS += commands_this_tick
      total_delta += commands_this_tick

      #break if total_delta > 100
    #end

    self.time_since_last_process = Time.now

    duration = Time.now - start

    since_time = (Time.now - self.time_since_last_stat)

    if since_time > 1.0
      self.time_since_last_stat = Time.now
      old_count = self.count_since_last
      old_repl = self.confirmed_since_last

      self.count_since_last = $TOTAL_COMMANDS
      self.confirmed_since_last = $TOTAL_REPLYS

      per_tick = ($TOTAL_COMMANDS - old_count)
      per_tick_rep = ($TOTAL_REPLYS - old_repl)

      puts "WRITE took #{duration.round}s #{total_delta} #{$TOTAL_COMMANDS} --- #{per_tick}/per-tick  #{per_tick_rep}/replyd (#{self.full_commands_waiting_to_be_written_to_minecraft.length})"

      if per_tick > per_tick_rep
        sleep 1.0/1.0
      end
    end

    sleep 1.0/120.0
  end

  def broadcast_latest_stdout(writable_io)
    client = self.clients[writable_io]

    unless client.nil? || client.broadcast_scanner.eos?
      while has_eol = client.broadcast_scanner.check_until(/\n/)
        broadcast_line = client.broadcast_scanner.scan_until(/\n/)
        if broadcast_line.include?("X:") ||
           broadcast_line.include?("Y:") ||
           broadcast_line.include?("Z:") ||
           broadcast_line.include?("Pitch:") ||
           broadcast_line.include?("The block at") ||
           broadcast_line.include?("found the block") ||
           broadcast_line.include?("successfully summoned") ||
           broadcast_line.include?("CONSOLE issued server command")
          begin
            if client.async
            else
              #puts "response >> #{broadcast_line}"
              writable_io.write(broadcast_line)
            end
          rescue Errno::ECONNRESET, Errno::EPIPE, IOError => e
            # Broken pipe (Errno::EPIPE)
            close_client(writable_io, e)
          end
        end
      end
    end
  end

  def enqueue_input_for_minecraft(io, bytes)
    self.input_waiting_to_be_written_to_minecraft[io] ||= StringScanner.new("")

    client = self.clients[io]

    if client.async
      if client.gzip_pump == nil
        #rp, wp = IO.pipe
        #client.gzip_pump = Zlib::Inflate.new
      else
        #self.clients[client_io].gzip_sink = wp
        #client.gzip_sink.write(bytes)
        #bytes = client.gzip_pump.read_partial(1024)
        #bytes = client.gzip_pump.inflate(bytes)

        if bytes == nil
          puts "!@#!@#!@#!@#!@#"
        end
      end
    end

    self.input_waiting_to_be_written_to_minecraft[io] << bytes
  end

  def close_client(readable_io, exception = nil)
    self.clients.delete(readable_io)
    readable_io.close unless readable_io.closed?
  end

  def write_minecraft_command(actual_command_line)
    @count += 1
    filtered_sent_line = actual_command_line.gsub(/[^a-zA-Z0-9\ _\-:\?\{\}\[\],\.\!\"\'\n]/, '')
    if (filtered_sent_line && filtered_sent_line.length > 0)
      begin
        self.minecraft_stdin.write(filtered_sent_line + "\n") #TODO: nonblock writes
      rescue Errno::EPIPE => e
        puts "minecraft exited"
        exit 1
      end
    end
  end
end
