#!/usr/local/bin/ruby

# Name:         vortex (VBoxManage ORchestration Tool EXtender)
# Version:      1.0.6
# Release:      1
# License:      Open Source
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Ruby script wrapper for creating and running
#               Virtual Box VMs in headless mode

# Changes:      1.0.0 Tue 20 Nov 2012 16:37:37 EST
#               Initial version
#               1.0.1 Sat 24 Nov 2012 20:20:19 EST
#               First working version with Solaris 10 U9 support
#               1.0.2 Tue 27 Nov 2012 08:26:27 EST
#               Dynamic variable names, function names, and requires working
#               1.0.3 Tue 27 Nov 2012 14:52:02 EST
#               Seperated OS specific install instruction into modules
#               1.0.4 Fri 30 Nov 2012 11:12:58 EST
#               Replaced case statement with if statements
#               1.0.5 Mon  3 Dec 2012 12:47:47 EST
#               Initial commit
#               1.0.6 Mon  3 Dec 2012 15:51:24 EST
#               Updated version with remote version checking

require 'rubygems'
require 'pty'
require 'expect'
require 'getopt/std'
require 'socket'
require 'open-uri'

class String
  def strip_control_characters()
    self.chars.inject("") do |str, char|
      unless char.ascii_only? and (char.ord < 32 or char.ord == 127)
        str << char
      end
      str
    end
  end 
  def strip_control_and_extended_characters()
    self.chars.inject("") do |str, char|
      if char.ascii_only? and char.ord.between?(32,126)
        str << char
      end
      str
    end
  end
end

# Global variables

$iso_dir="/Users/spindler/Documents/ISOs"
$sol10u9_iso="#{$iso_dir}/sol-10-u9-ga-x86-serial-dvd.iso"
$default_memory_size="1024"
$default_disk_size="10000"
$default_disk_type="ide"
$verbose=0

# Routine to send output to serial socket and log

def send_to_socket(string,line,socket,session_log)
  socket.puts("#{string}")
  socket.flush
  if $verbose == 1
    if line =~ /[A-z]/
      session_log.puts("FOUND: '#{line}'")
    end
    session_log.puts("SENT:  '#{string}'")
    session_log.flush
  end
end

# Get code name

def get_code_name
  command="cat #{$0} |grep '^# Name' |awk '{print $3}'"
  $code_name=%x[#{command}]
  $code_name.chomp!
end

get_code_name

# Load methods

if Dir.exists?("./methods")
  file_list=Dir.entries("./methods")
  for file in file_list
    if file =~/rb$/
      require "./methods/#{file}"
    end
  end
end

# Print usage

def print_usage
  script_name=$0
  puts
  puts "Usage: #{$code_name} -[n|r] -[b|c|d|e|f|h|i|j|l|m|n|o|u|v|y|z]"
  puts
  puts "-h: Print help"
  puts "-d: Disk size"
  puts "-c: Disk controller type"
  puts "-r: Memory size"
  puts "-f: Use a predefined OS type (from methods directory)"
  puts "-o: Operating System"
  puts "-m: Create/Make VM (Instantiate a VM)"
  puts "-n: Name of host"
  puts "-b: Build VM (Install OS)"
  puts "-s: Shutdown VM"
  puts "-V: Print verbose version"
  puts "-v: Print version"
  puts "-z: Run in debug mode (verbose output and/or logging)"
  puts "-e: Destroy VM"
  puts "-i: Attach ISO"
  puts "-y: Answer yes to questions"
  puts 
  puts "Defaults: Memory=#{$default_memory_size}"
  puts
  puts "Example: Create a predefined  VM with hostname sol10u9vm01"
  puts
  puts "#{script_name} -n sol10u9vm01 -f sol10u9 -m"
  puts
  puts "Example: Build VM named sol10u9vm01 in headless mode with"
  puts "predefined sol10u9 method and connect to console"
  puts "(methods are ruby code and reside in methods directory)"
  puts
  puts "#{script_name} -n sol10u9vm01 -f sol10u9 -b"
  puts
  puts "Example: Destroy VM named sol10u9vm01"
  puts
  puts "#{script_name} -n sol10u9vm01 -e"
  puts
  puts "Example: Shutdown VM named sol10u9vm01"
  puts
  puts "#{script_name} -n sol10u9vm01 -s"
  puts
  exit
end

# Get command line options and handle exception for incorrect options

begin
  opt = Getopt::Std.getopts("n:c:i:d:f:o:behlmOrsuvVyz")
rescue
  print_usage
end

# If give no command line options print help

if opt.empty?
  print_usage
end

# Convert a code to octal

if opt["O"]
  print "Input character: "
  char=gets.chomp
  exit
end

# Set verbose flag if given -z

if opt["z"]
  $verbose=1
end

# Routine to attach CD/DVDROM (ISO) to VM

def attach_cd_to_vm(host_name,iso_file)
  disk_type="ide"
  if host_name !~/[A-z]/
    puts "Host name of VM must be specified"
    return
  end
  if ! File.exists?(iso_file)
    puts "File: #{iso_file} does not exist"
    return
  end
  command="VBoxManage storageattach \"#{host_name}\" --storagectl \"#{disk_type}\" --port 0 --device 1 --type dvddrive --medium \"#{iso_file}\""
  system("#{command}")
end

# If given -i attach CD/DVDROM (ISO) to VM
# Requires -n (VM name) also

if opt["i"]
  iso_file=opt["i"]
  host_name=opt["n"]
  attach_cd_to_vm(host_name,iso_file)
  exit
end

# If given -h print help

if opt["h"]
  print_usage
end

# If given -V print verbose version information

if opt["V"]
  command="cat #{$0} |grep -A 12 '^# Name' |sed 's/^#//g'"
  info_string=%x[#{command}]
  puts
  puts info_string
  puts
  exit
end

# List VMs

if opt["l"]
  command="VBoxManage list vms"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  exit
end

# If given -v print version infomration

if opt["v"]
  local_version=get_local_version
  puts local_version
  exit
end

# Routine to get VM directory

def get_vm_dir(host_name)
  command="VBoxManage list systemproperties |grep 'Default machine folder' |cut -f2 -d'':'' |sed 's/^[ 	]*//g'"
  vm_base_dir=%x[#{command}]
  vm_base_dir=vm_base_dir.chomp
  vm_dir="#{vm_base_dir}/#{host_name}"
  return(vm_dir)
end

def unregister_vm(host_name)
  command="VBoxManage unregistervm #{host_name} --delete"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end

# Routine to remove VM

def remove_vm(host_name)
  if $yes_to_all == 1
    answer="y"
  end
  command="VBoxManage list vms"
  host_list=%x[#{command}]
  if !host_list.match(host_name)
    puts "Host \"#{host_name}\" is not registered"
  else
    while answer !~/y|Y|n|N/
      print "Are you sure you want to delete VM #{host_name}? (y/n): "
      answer=gets.chomp
    end
    if answer =~/y|Y/
      unregister_vm(host_name)
    end
  end
  vm_dir=get_vm_dir(host_name)
  vbox_file="#{vm_dir}/#{host_name}.vbox"
  if File.exists?(vbox_file)
    while answer !~/y|Y|n|N/
      puts "Found unregistered VM config file for #{host_name}"
      print "Remove \"#{vbox_file}\"? (y/n)"
      answer=gets.chomp
    end
    if answer =~/y|Y/
      system("rm \"#{vbox_file}\"")
    end
  end
  return
end

if opt["y"]
  $yes_to_all=1
end

# Code to update script from git

def get_local_version
  command="cat #{$0} |grep '^# Version' |awk '{print $3}'"
  local_version=%x[#{command}]
  return local_version
end

def update_script
  local_version=get_local_version
  file=open("https://github.com/richardatlateralblast/#{$code_name}/raw/master/version")
  remote_version=file.read
  puts
  puts "Checking for updated version of script..."
  puts
  puts "Local version:  #{local_version}"
  puts "Remote version: #{remote_version}"
  puts
  local_int=local_version.gsub(/\./,"")
  remote_int=remote_version.gsub(/\./,"")
  local_int=local_int.to_i
  remote_int=remote_int.to_i
  if remote_int == local_int
    puts "Remote and local versions of #{$code_name} are the same"
  end
  if remote_int > local_int
    puts "Remote version of #{$code_name} is greater"
  end
  puts
  return
end

if opt["u"]
  update_script
  exit
end

# If given -r remove VM

if opt["e"]
  host_name=opt["n"]
  remove_vm(host_name)
  exit
end

# Check if a VM exists

def check_vm_exists(host_name)
  command="VBoxManage list vms"
  host_list=%x[#{command}]
  if !host_list.match(host_name)
    puts "VM #{host_name} does not exist"
    exit
  end
end

# Check if a VM doesn't exist

def check_vm_doesnt_exist(host_name)
  command="VBoxManage list vms"
  host_list=%x[#{command}]
  if host_list.match(host_name)
    puts "VM #{host_name} already exists"
    exit
  end
end

# Routine to remove CD from VM

def remove_iso_from_vm(host_name)
  command="VBoxManage storageattach #{host_name} --storagectl ide --port 0 --device 1 --medium none"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end

# Routine to shut down VM

def shutdown_vm(host_name)
  command="VBoxManage list runningvms |grep \"#{host_name}\" |awk '{print $1}'"
  host_list=%x[#{command}]
  if host_list =~ /#{host_name}/
    command="VBoxManage controlvm #{host_name} poweroff"
    if $verbose == 1
      puts "Executing: #{command}"
    end
    system("#{command}")
  else
    if $verbose == 1
      puts "VM #{host_name} already shudown"
    end
  end
  return
end

# If given -s shutdown VM

if opt["s"]
  host_name=opt["n"]
  shutdown_vm(host_name)
  exit
end

# Routine to get VM info

def get_vm_value(hostname,option)
  command=""
  vm_config=vbox_cmd()
end

# Handle OS type
# If given list as an option print a list of OS types

if opt["o"] =~/^list$/
  system("VBoxManage list ostypes")
end

# If not give a disk type asume IDE

if ! opt["c"]
  opt["c"]="ide"
end

# Routine to get controller type

def get_controller(disk_type)
  if disk_type =~/ide/
    controller="PIIX4"
  end
  if disk_type =~/sata/
    controller="IntelAhci"
  end
  if disk_type =~/scsi/
    controller="LsiLogic"
  end
  return(controller)
end


# Routine to register VM

def register_vm(host_name,os_type)
  command="VBoxManage createvm --name \"#{host_name}\" --ostype \"#{os_type}\" --register"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end

# Routine to add a controller to a VM

def add_controller_to_vm(host_name,disk_type,controller)
  command="VBoxManage storagectl \"#{host_name}\" --name \"#{disk_type}\" --add \"#{disk_type}\" --controller \"#{controller}\""
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end  

# Routine to create a disk

def create_hdd(disk_name,disk_size)
  command="VBoxManage createhd --filename \"#{disk_name}\" --size \"#{disk_size}\""
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end 

# Routine to add a hdd to a VM

def add_hdd_to_vm(host_name,disk_type,disk_name)
  command="VBoxManage storageattach \"#{host_name}\" --storagectl \"#{disk_type}\" --port 0 --device 0 --type hdd --medium \"#{disk_name}\""
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end 

# Routine to add an iso to a machie

def add_iso_to_vm(host_name,disk_type,iso_file)
  if ! File.exists?(iso_file)
    puts "ISO File: #{iso_file} does not exist"
    exit
  end
  command="VBoxManage storageattach \"#{host_name}\" --storagectl \"#{disk_type}\" --port 0 --device 1 --type dvddrive --medium \"#{iso_file}\""
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end 

# Routine to add memory to a VM

def add_memory_to_vm(host_name,memory_size)
  command="VBoxManage modifyvm \"#{host_name}\" --memory \"#{memory_size}\""
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end  

# Routine to add a socket to a VM

def add_socket_to_vm(host_name)
  socket_name="/tmp/#{host_name}"
  command="VBoxManage modifyvm \"#{host_name}\" --uartmode1 server #{socket_name}"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return(socket_name)
end

# Routine to add serial to a VM

def add_serial_to_vm(host_name)
  command="VBoxManage modifyvm \"#{host_name}\" --uart1 0x3F8 4"
  if $verbose == 1
    puts "Executing: #{command}"
  end
  system("#{command}")
  return
end

# Make/Create a VM - entire process

if opt["m"]
  host_name=opt["n"]
  if opt["f"]
    os_type=opt["f"]
    iso_file, os_type, memory_size, disk_size, disk_type = eval("define_parameters_#{os_type}") 
  end
  if opt["o"]
    os_type=opt["o"]
  end
  if opt["r"]
    memory_size=opt["r"]
  end
  if opt["d"]
    disk_size=opt["d"]
  end
  if opt["c"]
    disk_type=opt["c"]
  end
  if opt["i"]
    iso_file=opt["i"]
  end
  vm_dir=get_vm_dir(host_name)
  disk_name="#{vm_dir}/#{host_name}.vdi"
  socket_name="/tmp/#{host_name}"
  controller=get_controller(disk_type)
  check_vm_doesnt_exist(host_name)
  register_vm(host_name,os_type)
  add_controller_to_vm(host_name,disk_type,controller)
  create_hdd(disk_name,disk_size)
  add_hdd_to_vm(host_name,disk_type,disk_name)
  add_iso_to_vm(host_name,disk_type,iso_file)
  add_memory_to_vm(host_name,memory_size)
  socket_name=add_socket_to_vm(host_name)
  add_serial_to_vm(host_name)
  exit
end

def boot_vm(host_name)
  command="VBoxManage startvm #{host_name} --type headless"
  system("#{command}")
  return
end

# If not creating a machine, build it
# Handle opening socket and exception if socket doesn't exist

def build_vm(host_name,os_type)
  check_vm_exists(host_name)
  shutdown_vm(host_name)
  host_value={}
  host_default={  "ip"=>["IP Address","192.168.1.2",""],
                  "netmask"=>["Netmask","255.255.255.0",""],
                  "gateway"=>["Gateway","192.168.1.254",""],
                  "domain"=>["Domain","home.net",""],
                  "nameservice"=>["Name Service","DNS","NIS+,NIS,DNS,LDAP,None"],
                  "nameserver"=>["Name Server","192.168.1.254",""],
                  "timezone"=>["Time Zone","Australia",""],
                  "region"=>["Geographic Region","Australasia",""],
                  "state"=>["Victoria","Victoria",""],
                  "password"=>["Password","penguins",""],
                  "filesystem"=>["Filesystem","ZFS","ZFS,UFS"]
  }
  host_default.each do |name,value|
    question=value[0]
    default=value[1]
    valid=value[2]
    if $yes_to_all == 1
      answer=default
      correct=1
    else
      correct=0
    end
    while correct!= 1 do
      print "#{question} [#{default}]: "
      answer=gets.chomp
      if valid =~/[A-z]|[0-9]/
        if answer !~/[A-z]|[0-9]/
          answer=default
        end
        if valid !~/#{answer}/
          puts "Valid answers are: #{valid}"
          correct=0
        else
          correct=1
        end
      else
        if answer !~/[A-z]|[0-9]/
          answer=default
          correct=1
        else
          if name =~/ip|netmask|gateway|nameserver/
            test=answer.split('.').map(&:to_i)
            if test[0] > 255 || test[1] > 255 || test[2] > 255 || test[3] > 255 || answer=~/[A-z]/
              puts "Invalid IP Address"
              correct=0
            end
          else
            correct=1
          end
        end
      end
    end
    if name=~/ip/
      if answer !=default
        new_gateway=answer.split('.')
        new_gateway="#{new_gateway[0]}.#{new_gateway[1]}.#{new_gateway[2]}.254"
        host_default['gateway']=["#{question}","#{new_gateway}"]
      end
    end
    host_value[name]=answer
  end
  boot_vm(host_name)
  eval("process_serial_#{os_type}(host_name,host_value)")
end

# If given a -b build VM

if opt["b"]
  host_name=opt["n"]
  os_type=opt["f"]
  build_vm(host_name,os_type)
  exit
end

