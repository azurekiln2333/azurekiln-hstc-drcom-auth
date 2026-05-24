# HSTC Dr.COM / CAS Auth Research Notes

Last updated: 2026-05-25

This file records the important context discovered while adapting the OpenWrt LuCI package for HSTC Dr.COM web authorization and CAS login. It intentionally avoids storing real usernames or passwords.

## Quick Resume Summary

- Latest committed package is `1.0.22-1`: `release/luci-app-drcom-auth_1.0.22-1_all.ipk`.
- The latest UI supports Simplified Chinese, Traditional Chinese, and English.
- Public key refresh is available in the LuCI CAS section. The cached key is stored at `/usr/share/drcom-auth/info/public_key.pem`.
- Public key status is deliberately returned by the backend as machine-readable text: `updated<TAB>mtime<TAB>path`. The LuCI frontend translates it into the selected language.
- CAS login must always fetch a fresh login page and extract `execution`, `currentMenu`, and `failN`; `execution` is session-flow state and cannot be hardcoded.
- CAS password ciphertext changes every login because browser-side RSA encryption uses randomized padding. This is expected, not a password mutation.
- Runtime CAS login needs an `openssl` command. On the observed Kwrt feed, install `openssl-util`; `opkg install openssl` is not valid there.
- Generated runtime files must stay under `/usr/share/drcom-auth`. Do not derive `SCRIPT_DIR` from `$0` inside generated `config.sh`, because init-script commands would otherwise drift into `/etc/info`.
- The local worktree still has unrelated old `release/` delete/add states. Use `git commit --only <paths...>` for focused commits until that is cleaned up intentionally.

## Current Package State

- Current package: `release/luci-app-drcom-auth_1.0.22-1_all.ipk`
- SHA256: `41dfe57b35dd25e466f032dfb1a7cfea9c461393cdae8f2e03e1a5140984c7e6`
- Current package source version: `1.0.22-1`
- Main package path: `openwrt/luci-app-drcom-auth`
- Local packaging script: `openwrt/package_ipk.ps1`

Recent relevant commits:

- `44655e1 fix(luci): localize public key status`
- `0adc5bb fix(luci): persist public key update status`
- `18d3700 fix(auth): keep runtime paths under app directory`
- `613802c fix(luci): report public key refresh failures`
- `fe60ae9 docs: update Kwrt openssl package notes`
- `1866f45 fix(package): remove hard openssl util dependency`
- `bf2c12c docs: add CAS auth research notes`
- `df17899 feat(luci): add CAS public key refresh`
- `df9b939 fix(auth): fetch CAS execution and encrypt password`
- `f27c5a4 fix(luci): clarify web authorize step errors`
- `121b0b9 fix(luci): show only authorize URL result`
- `83a40dd refactor(auth): isolate authorize URL retrieval`

## Important Files

- LuCI UI: `openwrt/luci-app-drcom-auth/htdocs/luci-static/resources/view/drcom-auth-v114.js`
- Init/backend commands: `openwrt/luci-app-drcom-auth/root/etc/init.d/drcom_auth`
- Default UCI config: `openwrt/luci-app-drcom-auth/root/etc/config/drcom_auth`
- Authorize URL fetch: `openwrt/luci-app-drcom-auth/root/usr/share/drcom-auth/get_authorize_url.sh`
- Full auth flow: `openwrt/luci-app-drcom-auth/root/usr/share/drcom-auth/auto_login_and_verify.sh`
- CAS login flow: `openwrt/luci-app-drcom-auth/root/usr/share/drcom-auth/hscas_login.sh`
- Bundled CAS public key: `openwrt/luci-app-drcom-auth/root/usr/share/drcom-auth/public_key.pem`

Runtime-generated files on OpenWrt:

- Config: `/usr/share/drcom-auth/config.sh`
- Cached public key: `/usr/share/drcom-auth/info/public_key.pem`
- Cookie jar: `/usr/share/drcom-auth/info/cookie.txt`
- Headers: `/usr/share/drcom-auth/info/headers.txt`
- Logs: `/usr/share/drcom-auth/logs/`
- Responses: `/usr/share/drcom-auth/responses/`

Important path note:

- `config.sh` must set `SCRIPT_DIR` to the fixed application directory `/usr/share/drcom-auth`.
- Do not compute it from `$0` inside generated `config.sh`; when `/etc/init.d/drcom_auth` sources the config, `$0` points to the init script and runtime files drift into `/etc/info` or `/etc/responses`.

## Main Discovery

The Dr.COM portal returns a CAS web authorization URL. The URL looks like:

```text
https://hscas.hstc.edu.cn/cas/login?service=http%3A%2F%2F192.168.2.34%3A801%2Feportal%2Fportal%2Fcas%2Flogin%3Fstate%3D...
```

The original problem was that LuCI showed output like:

```text
获取成功: Mon May 25 ... Current directory ...
Current WAN PORT ...
Current WAN IP address ...
Current Username: https://hscas...
```

Root cause:

- `config.sh` logged status through `tee -a`.
- When scripts sourced `config.sh`, those log lines went to stdout.
- LuCI treated stdout as the authorize URL result.

Fix:

- `output_status` in generated `config.sh` now writes only to the log file.
- LuCI extracts the last `http(s)://...` URL from command output as a defensive fallback.

## CAS Login Requirements

The HSTC CAS login page uses dynamic values. A fixed `LOGIN_POSTBODY` field structure is OK, but two values cannot be static:

- `execution`: hidden field from the current CAS login page. It changes per login flow/session.
- `password`: must be RSA encrypted before submission.

Observed login page behavior:

- CAS page loads `JSEncrypt`.
- `encryptEnabled = true`.
- Browser fetches the public key from:

```text
https://hscas.hstc.edu.cn/cas/jwt/publicKey
```

- Before submit, browser transforms the password to:

```text
__RSA__<base64-rsa-ciphertext>
```

Password ciphertext changes every time. This is normal because RSA PKCS#1 v1.5 encryption uses random padding.

## CAS POST Body

The field structure remains:

```text
username=$USERNAME
password=$ENCRYPTED_PASSWORD
currentMenu=$CURRENT_MENU
failN=$FAIL_N
execution=$EXECUTION
_eventId=submit
geolocation=
submit=登录
```

Historically the config used:

```sh
LOGIN_POSTBODY="username=$USERNAME&password=$PASSWORD&currentMenu=1&failN=0&execution=$EXECUTION&_eventId=submit&geolocation=&submit=%E7%99%BB%E5%BD%95"
```

The current implementation keeps this shape but fills dynamic values at runtime.

## Current Login Flow

Implemented in `hscas_login.sh`:

1. Receive `AUTHORIZE_URI` from Dr.COM authorize URL step.
2. GET `AUTHORIZE_URI` with cookies enabled.
3. Save the CAS login page to `LOGIN_PAGE_CONTENT`.
4. Extract:
   - `execution`
   - `currentMenu`
   - `failN`
5. Load public key:
   - Prefer cached `/usr/share/drcom-auth/info/public_key.pem`.
   - If missing, copy bundled `/usr/share/drcom-auth/public_key.pem`.
   - If still missing, request `HSCAS_PUBLIC_KEY_URL`.
6. Encrypt password with `openssl`:
   - First try `openssl pkeyutl -encrypt -pubin ... -pkeyopt rsa_padding_mode:pkcs1`.
   - Fallback to `openssl rsautl -encrypt -pubin ... -pkcs`.
7. POST to `AUTHORIZE_URI` with the same cookie jar.
8. If HTTP `302`, read `Location` from headers and verify ticket.
9. If HTTP `200` and success markers exist, GET `AUTHORIZE_URI` again to obtain ticket.

The package does not hard-depend on `openssl-util` because some OpenWrt feeds do not expose that package name. Runtime CAS login still requires an `openssl` command for RSA password encryption. If `openssl` is missing, `hscas_login.sh` exits with a clear error.

## Kwrt / OpenWrt Device Notes

Test device observed from SSH banner:

- Firmware: `Kwrt 03.14.2026 by Kiddin'`
- Feed URLs: `https://dl.openwrt.ai/releases/25.12/...`
- Target: `x86/64`
- Kernel/feed path shown by opkg: `6.12.71`
- Router LAN IP: `10.0.0.1`
- WAN IP during testing: `192.168.104.112`

Important package discovery:

- `which openssl` initially returned nothing.
- `opkg install openssl` failed with `Unknown package 'openssl'`.
- `opkg list | grep -Ei '^openssl|openssl.*util|libopenssl'` showed:
  - `openssl-util - 3.5.6-r1`
  - `libopenssl3 - 3.5.6-r1`
  - other OpenSSL-related library/provider packages
- Conclusion: on this Kwrt feed, the package that should provide `/usr/bin/openssl` is `openssl-util`, not `openssl`.

Recommended device commands:

```sh
opkg update
opkg install openssl-util
which openssl
openssl version
```

Then install or reinstall the LuCI package:

```sh
opkg install /tmp/upload.ipk
opkg install --force-reinstall /tmp/upload.ipk
```

Why the LuCI package does not depend on `openssl-util` anymore:

- Earlier package `1.0.17-1` had `Depends: libc, luci-base, curl, openssl-util`.
- The device initially reported `pkg_hash_check_unresolved: cannot find dependency openssl-util`.
- Later `opkg update` showed `openssl-util` exists in the configured feeds.
- To keep the package installable even when a feed lacks that exact package name, `1.0.18-1` removed the hard dependency.
- Runtime auth still requires an `openssl` executable; missing `openssl` is now reported during CAS auth instead of blocking LuCI package installation.

## Public Key Handling

The current public key is bundled in:

```text
openwrt/luci-app-drcom-auth/root/usr/share/drcom-auth/public_key.pem
```

LuCI CAS section now has:

- `公钥地址`
- `更新公钥`
- `公钥状态`

Default URL:

```text
https://hscas.hstc.edu.cn/cas/jwt/publicKey
```

Backend command:

```sh
/etc/init.d/drcom_auth public_key
```

This updates:

```text
/usr/share/drcom-auth/info/public_key.pem
```

Status command:

```sh
/etc/init.d/drcom_auth public_key_status
```

This prints the cached public key update time when the file exists, for example:

```text
updated	2026-05-25 07:30:12	/usr/share/drcom-auth/info/public_key.pem
```

The status output is intentionally machine-readable. LuCI formats it in the currently selected UI language, for example:

- Simplified Chinese: `公钥已更新：2026-05-25 07:30:12（/usr/share/drcom-auth/info/public_key.pem）`
- Traditional Chinese: `公鑰已更新：2026-05-25 07:30:12（/usr/share/drcom-auth/info/public_key.pem）`
- English: `Public key updated: 2026-05-25 07:30:12 (/usr/share/drcom-auth/info/public_key.pem)`

LuCI reads this command on page load so the `公钥状态` / `公鑰狀態` / `Public Key Status` row survives browser refreshes. If the cached key does not exist, the backend returns an empty success response and the UI shows the localized idle text such as `未更新`.

Rationale:

- Public key is safe to store locally.
- Avoids requesting the public key on every login.
- Still provides a UI/manual path to refresh if CAS rotates the key.

## LuCI UI Notes

The UI currently supports:

- Simplified Chinese
- Traditional Chinese
- English

The Simplified Chinese UI uses these sections:

- `基础设置`
- `网页授权链接获取`
  - Description: `上网第一步`
  - Button: `获取网页授权链接`
- `CAS 认证`
  - Account/password
  - Public key URL
  - Update public key button
  - Authenticate button
- `联网检测`
- `服务器设置`

Failure display was improved:

- Authorize and public key failures now show stdout/stderr/message where available.
- Public key refresh no longer prefixes a failed command result with `公钥已更新`; failures are shown as `公钥更新失败`.
- Public key refresh backend reports HTTP status on failure, for example `Update public key failed: ... (HTTP 403)`.
- Public key status is persisted by reading the cached key file modification time from `/usr/share/drcom-auth/info/public_key.pem`.
- Public key status is formatted by LuCI, not by the backend, so it follows the selected language.
- This helps expose script-level errors instead of only LuCI generic errors.

## Important Commands

Build package:

```powershell
cd openwrt
.\package_ipk.ps1
```

Check LuCI JS syntax:

```powershell
node --check .\openwrt\luci-app-drcom-auth\htdocs\luci-static\resources\view\drcom-auth-v114.js
```

Check shell syntax:

```powershell
bash -n .\openwrt\luci-app-drcom-auth\root\usr\share\drcom-auth\hscas_login.sh
bash -n .\openwrt\luci-app-drcom-auth\root\etc\init.d\drcom_auth
```

Inspect package contents:

```powershell
tar -tf .\release\ipk-debug\data.tar.gz
tar -xOf .\release\ipk-debug\control.tar.gz ./control
tar -xOf .\release\ipk-debug\data.tar.gz ./usr/share/drcom-auth/hscas_login.sh
```

OpenWrt/Kwrt install checks:

```sh
opkg install /tmp/upload.ipk
/etc/init.d/drcom_auth public_key
/etc/init.d/drcom_auth authorize
which openssl
openssl version
```

If `/tmp/upload.ipk` is already installed:

```sh
opkg install --force-reinstall /tmp/upload.ipk
```

## Known Open Questions / Test Gaps

- Full CAS login cannot be verified locally without a real account/password and campus network conditions.
- Need OpenWrt device testing of:
  - `/etc/init.d/drcom_auth authorize`
  - `/etc/init.d/drcom_auth public_key`
  - `/etc/init.d/drcom_auth public_key_status`
  - `/etc/init.d/drcom_auth ticket`
  - LuCI buttons for authorize/public key/auth
- If CAS returns captcha, MFA, account-lock, or risk-control pages, the current script may need additional detection and user-facing error messages.
- If `openssl` is missing on the target OpenWrt build, install the package that provides the `openssl` command for that firmware/feed. Package names may differ by OpenWrt version.
- If `openssl pkeyutl` is unavailable in a target OpenWrt build, fallback `rsautl` is present but should still be verified on-device.

## Current Dirty Worktree Caveat

At the time these notes were written, the working tree had unrelated old `release/` package delete/add states for older versions such as `1.0.0` through `1.0.14` and staged old `1.0.7/1.0.8/1.0.9/1.0.13` artifacts. Those were intentionally not mixed into the recent feature/fix commits.

Use `git status --short` before any future commit and prefer `git commit --only <paths...>` if those release artifacts are still present.
