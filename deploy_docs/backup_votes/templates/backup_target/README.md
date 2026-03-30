## 🔐 SSH Client Configuration for Secure Backups (~/.ssh/config)

To ensure backups run non-interactively, predictably, and with a tight security posture, the backup target uses a hardened SSH host profile.

### Dedicated identity

- `User backup_ro`
uses a non-privileged account on the remote system.

- `IdentityFile ~/.ssh/rsync_denbi`
ensures only the ssh key generated for this backup process is used.

- `IdentitiesOnly yes`
prevents SSH from trying other keys.

### Automation-safe behavior

- `BatchMode yes`
disables password prompts. If auth fails, it fails fast instead of hanging.

- `ConnectTimeout 15`
prevents hanging forever on dead networks.

### Strict host verification

- `StrictHostKeyChecking yes`
refuses to connect if the host key changes unexpectedly.

- `CheckHostIP yes`
protects against DNS or IP spoofing.

- `HostKeyAlgorithms ssh-ed25519`
allows only modern, strong host keys.

### Attack surface reduction

- `PasswordAuthentication no`
keys only, no passwords.

- `ForwardAgent no`, `ForwardX11 no`
prevents credential or session forwarding.

- `GSSAPIAuthentication no`
avoids slow or noisy Kerberos attempts.

### Cryptographic hardening

Explicitly restricts: `KexAlgorithms`,`Ciphers`,`MACs`
to modern, authenticated, and well-reviewed options.

### Connection health
- `ServerAliveInterval 30`& `ServerAliveCountMax 3`
detects broken connections and aborts cleanly instead 
of hanging backups forever.