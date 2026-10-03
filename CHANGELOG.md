# Changelog

## 0.3.2 - 2026-10-03

- Usage via heredoc and now documents `-l`, `-u` and `-O`; `-o list` exits after listing; control character stripping tolerates invalid bytes

## 0.3.1 - 2026-10-03

- Restructured into `main` with a `$PROGRAM_NAME == __FILE__` guard, split out `create_vm` and `build_vm`, moved the build prompts into a table, validated the `nameservice`/`filesystem` answers exactly instead of as a regex, corrected the `State` prompt label, `$verbose`/`$yes_to_all` are now booleans, removed unused `remove_iso_from_vm`

## 0.3.0 - 2026-10-03

- Errors go to stderr with a non-zero exit status, failed `VBoxManage` steps abort, `-m` checks the OS type and ISO before creating anything, and `-m` no longer forces the controller to `ide` when `-c` is not given

## 0.2.9 - 2026-10-03

- Run `VBoxManage` with argument arrays instead of shell strings and parse its output in Ruby (no shell interpolation of host names or paths); shutdown now matches VM names exactly

## 0.2.8 - 2026-10-03

- Read the `# Name`/`# Version` header in Ruby instead of `cat`/`grep`/`awk`/`sed`; load `methods` relative to the script so it runs from any directory

## 0.2.7 - 2026-10-03

- Added `frozen_string_literal`, removed unused requires (`rubygems`, `pty`, `expect`) and replaced default globals with constants

## 0.2.6 - 2026-10-03

- Fixed remote version URL and handle network errors in `-u`

## 0.2.5 - 2026-10-03

- Implemented `-O`, removed dead code, default controller to PIIX4

## 0.2.4 - 2026-10-03

- Replaced `eval` with `send` and validate the `-f` method name

## 0.2.3 - 2026-10-03

- Wait up to 30 seconds for the serial socket after booting the VM

## 0.2.2 - 2026-10-03

- Compare versions part by part instead of stripping dots (1.0.10 vs 1.0.9)

## 0.2.1 - 2026-10-03

- Fixed gateway auto-fill replacing the gateway prompt label and validation

## 0.2.0 - 2026-10-03

- Fixed `remove_vm` reusing the previous answer for the second prompt

## 0.1.9 - 2026-10-03

- Fixed `sol10u9` discarding the result of control character stripping

## 0.1.8 - 2026-10-03

- Fixed `sol10u9` domain answer sending Ctrl-Z instead of Esc

## 0.1.7 - 2026-10-03

- Fixed `-i` exiting before `-m` could create the VM

## 0.1.6 - 2026-10-03

- Fixed `-r` memory size option not taking an argument

## 0.1.5 - 2026-10-03

- Require `-n` host name and match VM names exactly instead of by substring

## 0.1.4 - 2026-10-03

- Validate IP address format and handle EOF on input in `build_vm`

## 0.1.3 - 2026-10-03

- Use `URI.open` for the remote version check (`open` no longer fetches URLs)

## 0.1.2 - 2026-10-03

- Fixed `sol10u9` crashing in non-debug mode because the session log was nil

## 0.1.1 - 2026-10-03

- Moved `get_local_version` above its first use (`-v` was broken)

## 0.1.0 - 2026-10-03

- Fixed `unregister_vm` missing `=` in command assignment (`-e` was broken)

## 0.0.9 - 2026-10-03

- Replaced `Dir.exists?`/`File.exists?` (removed in Ruby 3.2) with `exist?`; script crashed on startup

## 0.0.8 - 2014-06-17

- Updated documentation and license

## 0.0.7 - 2012-12-03

- Updated version with remote version checking

## 0.0.6 - 2012-12-03

- Initial commit

## 0.0.5 - 2012-11-30

- Replaced case statement with if statements

## 0.0.4 - 2012-11-27

- Separated OS specific install instructions into modules

## 0.0.3 - 2012-11-27

- Dynamic variable names, function names, and requires working

## 0.0.2 - 2012-11-24

- First working version with Solaris 10 U9 support

## 0.0.1 - 2012-11-20

- Initial version
