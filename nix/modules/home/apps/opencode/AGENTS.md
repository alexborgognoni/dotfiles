# Global instructions

## sudo / root commands

This machine has a passwordless sudoers drop-in at
`/etc/sudoers.d/010-alex-nopasswd`. It covers exactly these binaries:

- `/usr/bin/apt`
- `/usr/bin/apt-get`
- `/usr/bin/systemctl`
- `/usr/bin/tee`

Run those directly with `sudo -n`. No askpass helper, no password prompt,
nothing to supply.

Rules:

- Never ask for, echo, print, or write the sudo password anywhere.
- No password file and no `OPENCODE_SUDO_PASS` env var exist for this machine.
  Do not create one.
- Everything outside the allow-list still requires a password. If a command is
  not covered, ask the user to run it themselves, or to extend the drop-in with
  `sudo visudo -f /etc/sudoers.d/010-alex-nopasswd` (they must do this in their
  own terminal — `visudo` needs root). Never try to work around the allow-list
  (no `sh -c`, no `tee` tricks to proxy an uncovered binary).
- Write files under `/etc` with `sudo -n tee`, e.g.
  `printf '%s\n' 'line' | sudo -n tee -a /etc/some.conf`.
- Never retry a rejected password. Repeated failures are logged and can lock
  the account.
