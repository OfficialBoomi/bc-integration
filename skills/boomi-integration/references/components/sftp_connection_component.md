# SFTP Connection Component

Component type: `connector-settings`
SubType: `officialboomi-X3979C-sftpvx-prod`

Not the SFTP (Legacy) or SFTP V2 (Retired) connectors; their components are not interchangeable with this one.

## XML Structure

```xml
<bns:Component xmlns:bns="http://api.platform.boomi.com/"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               componentId=""
               name="{connection-name}"
               type="connector-settings"
               subType="officialboomi-X3979C-sftpvx-prod"
               folderId="{folder-id}">
  <bns:encryptedValues/>
  <bns:object>
    <GenericConnectionConfig>
      <field id="remoteDirectory" type="string" value="/"/>
      <field id="host" type="string" value="{host}"/>
      <field id="port" type="integer" value="22"/>
      <field id="username" type="string" value="{username}"/>
      <field id="password" type="password" value=""/>
      <field id="authType" type="string" value="None"/>
      <field id="keyPath" type="string" value=""/>
      <field id="keyPswrd" type="password" value=""/>
      <field id="prvkeyContent" type="password" value=""/>
      <field id="keyContentPwd" type="password" value=""/>
      <field id="pubkeyContent" type="password" value=""/>
      <field id="keyPairName" type="string" value=""/>
      <field id="enablePooling" type="boolean" value="false"/>
      <field id="proxyEnable" type="boolean" value="false"/>
      <field id="proxyType" type="string" value=""/>
      <field id="proxyHost" type="string" value=""/>
      <field id="proxyPort" type="integer" value=""/>
      <field id="proxyuserName" type="string" value=""/>
      <field id="proxyPassword" type="password" value=""/>
      <field id="hostEntry" type="string" value=""/>
      <field id="connectionTimeout" type="integer"/>
      <field id="readTimeout" type="integer"/>
      <field id="kex" type="string" value="curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384,ecdh-sha2-nistp521,diffie-hellman-group-exchange-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512,diffie-hellman-group14-sha256"/>
      <field id="server_host_key" type="string" value="ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-512,rsa-sha2-256"/>
      <field id="cipher.s2c" type="string" value="aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com"/>
      <field id="cipher.c2s" type="string" value="aes128-ctr,aes192-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com"/>
      <field id="mac.s2c" type="string" value="hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1"/>
      <field id="mac.c2s" type="string" value="hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha1-etm@openssh.com,hmac-sha2-256,hmac-sha2-512,hmac-sha1"/>
      <field id="compression.s2c" type="string" value="none"/>
      <field id="compression.c2s" type="string" value="none"/>
      <field id="lang.s2c" type="string" value=""/>
      <field id="lang.c2s" type="string" value=""/>
      <field id="CheckKexes" type="string" value="sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,curve448-sha512"/>
      <field id="CheckMacs" type="string" value=""/>
      <field id="CheckCiphers" type="string" value="chacha20-poly1305@openssh.com"/>
      <field id="CheckSignatures" type="string" value="ssh-ed25519,ssh-ed448"/>
      <field id="sftpCustomConfiguration" type="customproperties">
        <customProperties/>
      </field>
    </GenericConnectionConfig>
  </bns:object>
</bns:Component>
```

- `authType="None"` is username/password authentication. For key authentication, have the user configure it in the GUI.
- `remoteDirectory` is a fallback only: a Sub Directory or Remote Directory document property replaces it. See `sftp_connector_operation_component.md` § Directory Resolution.

## Known Host Entry

`hostEntry` (GUI: **Known Host Entry**) pins the server's SSH host key. When blank, any host key the server presents is accepted. When set, a server whose key does not match is rejected before login.

The value is one known_hosts line: `{host} {algorithm} {base64-key}`, e.g. `sftp.example.com ssh-ed25519 AAAAC3Nz...`. A hashed line (`ssh-keyscan -H`) and a trailing comment also work.

- `{host}` must be the connection's `host` value. A different name, or the bracketed `[host]:22` form, is rejected.
- The algorithm token is required.
- An ed25519, ECDSA, or RSA key the server offers works without changing `server_host_key`.

Walk the user through it:

1. Get the host key line from the SFTP vendor or server admin. Alternatively, run `ssh-keyscan {host}`, pick one of the lines it returns, and have the user compare the `ssh-keygen -lf` fingerprint with the one the vendor publishes; a scanned key is unverified until it matches.
2. For a new connection, set `hostEntry` in the XML before the first push. For an existing connection, the user pastes the line into **Known Host Entry** on the Connection tab and saves (see Password Handling for why it is not pushed).
3. Deploy and run a process that uses the connection, then check the result:

| Text | Where it appears | Meaning |
|------|------------------|---------|
| `Permanently added '{host}' ... to the list of known hosts` | Process log | `hostEntry` is blank; no pin is in use |
| `HostKey has been changed: {host}` | Connector step document status message | The entry's host matched, but the server presented a different key |
| `reject HostKey: {host}` | Connector step document status message | No usable entry: wrong host, bracketed host, or a malformed line. There is no separate parse error |

With `returnApplicationErrors="true"`, a rejected host key arrives as a document with status `-1` and the execution still ends COMPLETE. Check document status, not execution status.

## Password Handling

Push new connections with `password` `value=""`, then have the user enter the password in the GUI. Never edit and re-push a pulled connection — the push stores the pulled hex token as the password, and the push guard does not catch it for this connector (`boomi_error_reference.md` Issue #39).
