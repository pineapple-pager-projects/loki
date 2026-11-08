# Deferred v2 actions (binary-dependent)

Moved out of the scanned `actions/` dir for the v2-no-binaries MVP because they
depend on shipped binaries / native crypto that v2 drops:

- ssh_connector.py / steal_files_ssh.py — paramiko (native cryptography/bcrypt/pynacl)
- rdp_connector.py — sfreerdp binary (no pure-Python/opkg RDP)
- smb_connector.py / steal_files_smb.py — smb2-cat/find/share-enum binaries

Re-add plan: SSH via on-device OpenSSH (/usr/bin/ssh + scp) subprocess; SMB via
pysmb (pure-Python, vendored). RDP: likely stays dropped on MIPS.
To restore one, move it back to actions/ and ensure its deps are satisfied.
