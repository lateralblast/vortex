def define_parameters_sol10u9()
  iso_file="#{$iso_dir}/sol-10-u9-ga-x86-serial-dvd.iso"
  os_type="Solaris_64"
  memory_size="1024"
  disk_size="10000"
  disk_type="ide"
  return iso_file, os_type, memory_size, disk_size, disk_type
end

def process_serial_sol10u9(host_name,host_value)
  if $verbose == 1
    session_log_file="/tmp/#{host_name}.session.log"
    if File.exists?(session_log_file)
      File.delete(session_log_file)
    end
    session_log = File.new(session_log_file,'w')
    puts "Logging to: #{session_log_file}"
  end
  begin
    socket=UNIXSocket.open("/tmp/#{host_name}")
  rescue
    puts "Cannot open socket"
    exit
  end
  socket.each_line do |line|
  	puts line
    if $verbose == 1
      sleep 0.05
    end
    line.strip_control_and_extended_characters
    session_log.puts(line)
    session_log.flush
  	if line =~ /Enter the number of your choice/
      send_to_socket("4",line,socket,session_log)
  	end
  	if line =~ /Traditional Chinese/
      send_to_socket("0",line,socket,session_log)
  	end
  	if line =~ /ANSI Standard CRT/
      send_to_socket("1",line,socket,session_log)
  	end
    if line =~ /the legend at the bottom of the screen/
      send_to_socket("\0332",line,socket,session_log)
    end
    if line =~ /information it cannot find/
      send_to_socket("\0332",line,socket,session_log)
    end
    if line =~ /follow the instructions listed/
      send_to_socket("\0332",line,socket,session_log)
    end
    if line =~ /DHCP support will not be enabled/
      send_to_socket("\0332",line,socket,session_log)
    end
  	if line =~ /A host name must have at least one character/
      string="#{host_name}\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /Enter the Internet Protocol/
      string=host_value['ip']
      string="#{string}\0332"
      send_to_socket(string,line,socket,session_log)
    end
  	if line =~ /System part of a subnet/ and line !~ /Yes/
      string="\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /A netmask must contain/
      string=host_value['netmask']
      if string !~ /255\.255\.255\.0/
        string="\010\010\010\010\010\010\010\010\010\010\010\010\010#{string}\0332"
      else
        string="\0332"
      end
      send_to_socket(string,line,socket,session_log)
    end
  	if line =~ /Enable IPv6 for/
      string="\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /Detect one upon reboot/
      string="\e[Bx\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /defaultrouter file/
      string=host_value['gateway']
      string="#{string}\0332"
      send_to_socket(string,line,socket,session_log)
    end
  	if line =~ /standard UNIX security/
      string="\0332"
      send_to_socket(string,line,socket,session_log)
    end
  	if line =~ /> Confirm the following information/
      string="\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /provide name service information/
      string=host_value['nameservice']
      if string =~ /DNS/
        string="\e[B\e[B"
      end
      string="#{string}x\0332"
      send_to_socket(string,line,socket,session_log)
    end
    if line =~ /domain where this system resides/
      string=host_value['domain']
      string="#{string}\0322"
      send_to_socket(string,line,socket,session_log)
    end
  end
end