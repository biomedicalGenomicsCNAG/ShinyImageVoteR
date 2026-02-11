## 🔐 Restricted SSH Key for Pull-Only Backups

To secure the process, the SSH public key installed on the backup target is restricted using authorized_keys options in the backup source, which are explained below:

- `from="<BACKUP_TARGET_IP>"`
The key is accepted only if the SSH connection originates from this IP.
=> Even if the key is compromised, it can’t be used from another machine.

- `command="/usr/bin/rrsync -ro <BACKUP_SOURCE_PATH>"`
Forces execution of rrsync in read-only mode and jails the session to
<BACKUP_SOURCE_PATH>.
=> Even if someone tries `ssh user@host rm -rf /`, it won’t run.

- `no-agent-forwarding`
Prevents SSH agent reuse => The key can’t be leveraged to hop elsewhere.

- `no-port-forwarding`
Disables SSH tunnels => No sneaky backchannels.

- `no-pty`
No interactive shell => only rrsync commands are allowed.

- `no-user-rc`, `no-X11-forwarding`
	=> Disables user startup scripts and GUI forwarding.