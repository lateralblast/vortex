![alt tag](https://raw.githubusercontent.com/lateralblast/vortex/master/vortex.jpg)

VORTEX
======

VBoxManage ORchestration Tool EXtender

Information
------------

Ruby script wrapper for creating and running Virtual Box VMs in headless mode.

This requires a serial console to be enabled on the VM. It connects via a socket
and drives an OS install.

License
-------

This software is licensed as CC-BA (Creative Commons By Attrbution)

http://creativecommons.org/licenses/by/4.0/legalcode

Usage
-----

```
$ vortex -[n|r] -[b|c|d|e|f|h|i|j|l|m|n|o|u|v|y|z]

-h: Print help
-d: Disk size
-c: Disk controller type
-r: Memory size
-f: Use a predefined OS type (from methods directory)
-o: Operating System
-m: Create/Make VM (Instantiate a VM)
-n: Name of host
-b: Build VM (Install OS)
-s: Shutdown VM
-V: Print verbose version
-v: Print version
-z: Run in debug mode (verbose output and/or logging)
-e: Destroy VM
-i: Attach ISO
-y: Answer yes to questions
```

Examples
--------

Create a predefined  VM with hostname sol10u9vm01:

```
$ vortex -n sol10u9vm01 -f sol10u9 -m
```

Build VM named sol10u9vm01 in headless mode with predefined sol10u9 method and
connect to console (methods are ruby code and reside in methods directory):

```
$ vortex -n sol10u9vm01 -f sol10u9 -b
```

Destroy VM named sol10u9vm01:

```
$ vortex -n sol10u9vm01 -e
```

Shutdown VM named sol10u9vm01:

```
$ vortex -n sol10u9vm01 -s
```

Requirements
------------

Ruby gems:

- rubygems
- pty
- expect
- getopt/std
- socket
- open-uri
