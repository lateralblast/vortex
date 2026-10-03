#!/usr/bin/env ruby
# frozen_string_literal: true

# Name:         vortex (VBoxManage ORchestration Tool EXtender)
# Version:      0.3.2
# Release:      1
# License:      CC BY-NC-SA 4.0 (Creative Commons Attribution-NonCommercial-ShareAlike)
#               https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
# Group:        System
# Source:       N/A
# URL:          http://lateralblast.com.au/
# Distribution: UNIX
# Vendor:       Lateral Blast
# Packager:     Richard Spindler <richard@lateralblast.com.au>
# Description:  Ruby script wrapper for creating and running
#               Virtual Box VMs in headless mode

require 'getopt/std'
require 'open-uri'
require 'socket'

# Strip helpers used by the OS methods on serial console output

class String
  def strip_control_characters
    scrub('').gsub(/[\u0000-\u001f\u007f]/, '')
  end

  def strip_control_and_extended_characters
    scrub('').gsub(/[^ -~]/, '')
  end
end

SCRIPT_PATH = File.realpath(__FILE__)
METHODS_DIR = File.join(File.dirname(SCRIPT_PATH), 'methods')
HEADER_SIZE = 13
OPTIONS     = 'n:c:i:d:f:o:r:behlmOsuvVyz'

DEFAULT_MEMORY_SIZE = '1024'
DEFAULT_DISK_SIZE   = '10000'
DEFAULT_DISK_TYPE   = 'ide'
DEFAULT_CONTROLLER  = 'PIIX4'
CONTROLLERS         = { 'ide' => 'PIIX4', 'sata' => 'IntelAhci', 'scsi' => 'LsiLogic' }.freeze

HOST_PROMPTS = {
  'ip'          => { label: 'IP Address', default: '192.168.1.2' },
  'netmask'     => { label: 'Netmask', default: '255.255.255.0' },
  'gateway'     => { label: 'Gateway', default: '192.168.1.254' },
  'domain'      => { label: 'Domain', default: 'home.net' },
  'nameservice' => { label: 'Name Service', default: 'DNS', valid: %w[NIS+ NIS DNS LDAP None] },
  'nameserver'  => { label: 'Name Server', default: '192.168.1.254' },
  'timezone'    => { label: 'Time Zone', default: 'Australia' },
  'region'      => { label: 'Geographic Region', default: 'Australasia' },
  'state'       => { label: 'State', default: 'Victoria' },
  'password'    => { label: 'Password', default: 'penguins' },
  'filesystem'  => { label: 'Filesystem', default: 'ZFS', valid: %w[ZFS UFS] }
}.freeze
IP_FIELDS = %w[ip netmask gateway nameserver].freeze

# Globals shared with the OS methods in the methods directory

$iso_dir    = '/Users/spindler/Documents/ISOs'
$verbose    = false
$yes_to_all = false

# Get a value from the script header (e.g. Name, Version)

def header_value(key)
  File.foreach(SCRIPT_PATH) do |line|
    return Regexp.last_match(1) if line =~ /^# #{key}:\s+(\S+)/
  end
  nil
end

CODE_NAME = header_value('Name')
VERSION   = header_value('Version')

Dir.glob(File.join(METHODS_DIR, '*.rb')).sort.each { |file| require file }

# Print an error to stderr and exit with failure

def die(message)
  warn message
  exit 1
end

def debug(message)
  puts message if $verbose
end

# Routine to send output to serial socket and log

def send_to_socket(string, line, socket, session_log)
  socket.puts(string)
  socket.flush
  return unless $verbose && session_log

  session_log.puts("FOUND: '#{line}'") if line.match?(/[A-Za-z]/)
  session_log.puts("SENT:  '#{string}'")
  session_log.flush
end

# Print usage

def print_usage(status = 0)
  script_name = $PROGRAM_NAME
  puts <<~USAGE

    Usage: #{CODE_NAME} -n <host name> -[b|e|i|l|m|O|s|u|v|V] [-c|-d|-f|-o|-r|-y|-z]

    -h: Print help
    -d: Disk size
    -c: Disk controller type
    -r: Memory size
    -f: Use a predefined OS type (from methods directory)
    -o: Operating System (list: print available types)
    -m: Create/Make VM (Instantiate a VM)
    -n: Name of host
    -b: Build VM (Install OS)
    -s: Shutdown VM
    -l: List VMs
    -u: Check for updated version
    -O: Convert a character to octal
    -V: Print verbose version
    -v: Print version
    -z: Run in debug mode (verbose output and/or logging)
    -e: Destroy VM
    -i: Attach ISO
    -y: Answer yes to questions

    Defaults: Memory=#{DEFAULT_MEMORY_SIZE} Disk=#{DEFAULT_DISK_SIZE} Controller=#{DEFAULT_DISK_TYPE}

    Example: Create a predefined  VM with hostname sol10u9vm01

    #{script_name} -n sol10u9vm01 -f sol10u9 -m

    Example: Build VM named sol10u9vm01 in headless mode with
    predefined sol10u9 method and connect to console
    (methods are ruby code and reside in methods directory)

    #{script_name} -n sol10u9vm01 -f sol10u9 -b

    Example: Destroy VM named sol10u9vm01

    #{script_name} -n sol10u9vm01 -e

    Example: Shutdown VM named sol10u9vm01

    #{script_name} -n sol10u9vm01 -s

  USAGE
  exit status
end

def print_verbose_version
  lines = File.readlines(SCRIPT_PATH, chomp: true)
  start = lines.index { |line| line.start_with?('# Name') }
  puts
  puts lines[start, HEADER_SIZE].map { |line| line.sub(/\A#/, '') }
  puts
end

# Convert a character to octal

def print_octal
  print 'Input character: '
  char = ($stdin.gets || '').chomp
  die 'No character given' if char.empty?

  puts format('%03o', char.ord)
end

# Routines to run VBoxManage without a shell, so arguments are never interpreted

def vbox(*args)
  debug("Executing: VBoxManage #{args.join(' ')}")
  result = system('VBoxManage', *args)
  die 'VBoxManage not found: is VirtualBox installed?' if result.nil?
  result
end

def vbox!(*args)
  vbox(*args) || die("VBoxManage #{args.first} failed")
end

def vbox_output(*args)
  IO.popen(['VBoxManage', *args], &:read)
rescue Errno::ENOENT
  die 'VBoxManage not found: is VirtualBox installed?'
end

# Routines to check VM names and state (exact name match)

def require_host_name(host_name)
  return if host_name&.match?(/[A-Za-z0-9]/)

  die 'Host name of VM must be specified (-n)'
end

def vm_names(kind = 'vms')
  vbox_output('list', kind).scan(/^"(.*)" \{/).flatten
end

def vm_registered?(host_name)
  vm_names.include?(host_name)
end

def vm_running?(host_name)
  vm_names('runningvms').include?(host_name)
end

def check_vm_exists(host_name)
  require_host_name(host_name)
  die "VM #{host_name} does not exist" unless vm_registered?(host_name)
end

def check_vm_doesnt_exist(host_name)
  require_host_name(host_name)
  die "VM #{host_name} already exists" if vm_registered?(host_name)
end

# Routine to ask a yes/no question ($yes_to_all answers yes)

def confirm(prompt)
  return true if $yes_to_all

  answer = ''
  until answer.match?(/\A[yn]\z/i)
    print prompt
    answer = ($stdin.gets || 'n').chomp
  end
  answer.casecmp?('y')
end

# Routine to check an OS method (from methods directory) exists

def check_method(os_type)
  name = os_type.to_s
  return if name.match?(/\A\w+\z/) &&
            respond_to?("define_parameters_#{name}", true) &&
            respond_to?("process_serial_#{name}", true)

  die "Unknown OS method: #{os_type}"
end

# Routine to get VM directory

def get_vm_dir(host_name)
  base_dir = vbox_output('list', 'systemproperties')[/^Default machine folder:\s*(.+)$/, 1]
  die 'Cannot determine default machine folder' if base_dir.nil?

  File.join(base_dir.strip, host_name)
end

def get_controller(disk_type)
  CONTROLLERS.fetch(disk_type, DEFAULT_CONTROLLER)
end

# Routine to remove VM

def remove_vm(host_name)
  require_host_name(host_name)
  if vm_registered?(host_name)
    if confirm("Are you sure you want to delete VM #{host_name}? (y/n): ")
      vbox!('unregistervm', host_name, '--delete')
    end
  else
    puts "Host \"#{host_name}\" is not registered"
  end
  vbox_file = File.join(get_vm_dir(host_name), "#{host_name}.vbox")
  return unless File.exist?(vbox_file)

  puts "Found unregistered VM config file for #{host_name}"
  File.delete(vbox_file) if confirm("Remove \"#{vbox_file}\"? (y/n): ")
end

# Routine to shut down VM

def shutdown_vm(host_name)
  if vm_running?(host_name)
    vbox!('controlvm', host_name, 'poweroff')
  else
    debug("VM #{host_name} already shut down")
  end
end

# Routines to create a VM

def require_iso(iso_file)
  die "ISO File: #{iso_file} does not exist" unless File.exist?(iso_file)
end

def register_vm(host_name, os_type)
  vbox!('createvm', '--name', host_name, '--ostype', os_type, '--register')
end

def add_controller_to_vm(host_name, disk_type, controller)
  vbox!('storagectl', host_name, '--name', disk_type, '--add', disk_type, '--controller', controller)
end

def create_hdd(disk_name, disk_size)
  vbox!('createhd', '--filename', disk_name, '--size', disk_size.to_s)
end

def add_hdd_to_vm(host_name, disk_type, disk_name)
  vbox!('storageattach', host_name, '--storagectl', disk_type, '--port', '0',
        '--device', '0', '--type', 'hdd', '--medium', disk_name)
end

def add_iso_to_vm(host_name, disk_type, iso_file)
  require_iso(iso_file)
  vbox!('storageattach', host_name, '--storagectl', disk_type, '--port', '0',
        '--device', '1', '--type', 'dvddrive', '--medium', iso_file)
end

def add_memory_to_vm(host_name, memory_size)
  vbox!('modifyvm', host_name, '--memory', memory_size.to_s)
end

def add_socket_to_vm(host_name)
  vbox!('modifyvm', host_name, '--uartmode1', 'server', "/tmp/#{host_name}")
end

def add_serial_to_vm(host_name)
  vbox!('modifyvm', host_name, '--uart1', '0x3F8', '4')
end

# Routine to attach CD/DVDROM (ISO) to VM

def attach_cd_to_vm(host_name, iso_file)
  require_host_name(host_name)
  add_iso_to_vm(host_name, DEFAULT_DISK_TYPE, iso_file)
end

# Make/Create a VM - entire process
# Command line options override the values from the OS method

def create_vm(opt)
  host_name = opt['n']
  require_host_name(host_name)
  iso_file = os_type = memory_size = disk_size = disk_type = nil
  if opt['f']
    check_method(opt['f'])
    iso_file, os_type, memory_size, disk_size, disk_type = send("define_parameters_#{opt['f']}")
  end
  os_type     = opt['o'] || os_type
  iso_file    = opt['i'] || iso_file
  memory_size = opt['r'] || memory_size || DEFAULT_MEMORY_SIZE
  disk_size   = opt['d'] || disk_size || DEFAULT_DISK_SIZE
  disk_type   = opt['c'] || disk_type || DEFAULT_DISK_TYPE
  die 'OS type must be specified (-f or -o)' if os_type.nil?
  die 'ISO file must be specified (-f or -i)' if iso_file.nil?
  require_iso(iso_file)
  check_vm_doesnt_exist(host_name)
  disk_name = File.join(get_vm_dir(host_name), "#{host_name}.vdi")
  register_vm(host_name, os_type)
  add_controller_to_vm(host_name, disk_type, get_controller(disk_type))
  create_hdd(disk_name, disk_size)
  add_hdd_to_vm(host_name, disk_type, disk_name)
  add_iso_to_vm(host_name, disk_type, iso_file)
  add_memory_to_vm(host_name, memory_size)
  add_socket_to_vm(host_name)
  add_serial_to_vm(host_name)
end

# Routines to build a VM

def boot_vm(host_name)
  vbox!('startvm', host_name, '--type', 'headless')
end

def valid_ip?(address)
  address.match?(/\A\d+\.\d+\.\d+\.\d+\z/) && address.split('.').all? { |octet| octet.to_i <= 255 }
end

# Ask for a host value, using the default if nothing is given or $yes_to_all is set

def ask(name, field)
  return field[:default] if $yes_to_all

  loop do
    print "#{field[:label]} [#{field[:default]}]: "
    answer = ($stdin.gets || '').strip
    answer = field[:default] if answer.empty?
    if field[:valid] && !field[:valid].include?(answer)
      puts "Valid answers are: #{field[:valid].join(',')}"
    elsif IP_FIELDS.include?(name) && !valid_ip?(answer)
      puts 'Invalid IP Address'
    else
      return answer
    end
  end
end

# Build the VM: ask for host values, boot headless and let the OS method
# drive the install over the serial socket

def build_vm(host_name, os_type)
  check_method(os_type)
  check_vm_exists(host_name)
  shutdown_vm(host_name)
  prompts    = HOST_PROMPTS.transform_values(&:dup)
  host_value = {}
  prompts.each do |name, field|
    answer = ask(name, field)
    # Default the gateway to .254 on the same subnet as a non-default IP
    prompts['gateway'][:default] = "#{answer.split('.')[0, 3].join('.')}.254" if name == 'ip' && answer != field[:default]
    host_value[name] = answer
  end
  boot_vm(host_name)
  send("process_serial_#{os_type}", host_name, host_value)
end

# Code to check for an updated version of the script from git

def update_script
  url = "https://raw.githubusercontent.com/lateralblast/#{CODE_NAME}/master/version"
  begin
    remote_version = URI.open(url, &:read).chomp
  rescue StandardError => e
    die "Could not check remote version: #{e.message}"
  end
  puts
  puts 'Checking for updated version of script...'
  puts
  puts "Local version:  #{VERSION}"
  puts "Remote version: #{remote_version}"
  puts
  local_parts  = VERSION.split('.').map(&:to_i)
  remote_parts = remote_version.split('.').map(&:to_i)
  puts "Remote and local versions of #{CODE_NAME} are the same" if remote_parts == local_parts
  puts "Remote version of #{CODE_NAME} is greater" if (remote_parts <=> local_parts).positive?
  puts
end

def parse_options
  Getopt::Std.getopts(OPTIONS)
rescue StandardError
  print_usage(1)
end

def main
  opt = parse_options
  print_usage(1) if opt.empty?
  print_usage if opt['h']
  $verbose    = true if opt['z']
  $yes_to_all = true if opt['y']
  return print_octal if opt['O']
  return puts(VERSION) if opt['v']
  return print_verbose_version if opt['V']
  return update_script if opt['u']
  return vbox!('list', 'vms') if opt['l']
  return vbox!('list', 'ostypes') if opt['o'] == 'list'
  return attach_cd_to_vm(opt['n'], opt['i']) if opt['i'] && !opt['m']
  return remove_vm(opt['n']) if opt['e']

  if opt['s']
    require_host_name(opt['n'])
    return shutdown_vm(opt['n'])
  end
  return create_vm(opt) if opt['m']
  return build_vm(opt['n'], opt['f']) if opt['b']

  print_usage(1)
end

main if $PROGRAM_NAME == __FILE__
