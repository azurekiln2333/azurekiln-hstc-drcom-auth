# HSTC Dr.COM / CAS Auth Research Notes

Last updated: 2026-05-25

This file records the important context discovered while adapting the OpenWrt LuCI package for HSTC Dr.COM web authorization and CAS login. It intentionally avoids storing real usernames or passwords.

## Current Package State

- Current package: `release/luci-app-drcom-auth_1.0.17-1_all.ipk`
- SHA256: `c8824cd9ca7a033187f5abfdc1df47920385a8b2e8bd3223f9d889feaf7bd8ba`
- Current package source version: `1.0.17-1`
- Main package path: `openwrt/luci-app-drcom-auth`
- Local packaging script: `openwrt/package_ipk.ps1`

Recent relevant commits:

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

The package now depends on `openssl-util`.

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

Rationale:

- Public key is safe to store locally.
- Avoids requesting the public key on every login.
- Still provides a UI/manual path to refresh if CAS rotates the key.

## LuCI UI Notes

The UI uses these sections:

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

## Known Open Questions / Test Gaps

- Full CAS login cannot be verified locally without a real account/password and campus network conditions.
- Need OpenWrt device testing of:
  - `/etc/init.d/drcom_auth authorize`
  - `/etc/init.d/drcom_auth public_key`
  - `/etc/init.d/drcom_auth ticket`
  - LuCI buttons for authorize/public key/auth
- If CAS returns captcha, MFA, account-lock, or risk-control pages, the current script may need additional detection and user-facing error messages.
- If `openssl pkeyutl` is unavailable in a target OpenWrt build, fallback `rsautl` is present but should still be verified on-device.

## Current Dirty Worktree Caveat

At the time these notes were written, the working tree had unrelated old `release/` package delete/add states for older versions such as `1.0.0` through `1.0.14` and staged old `1.0.7/1.0.8/1.0.9/1.0.13` artifacts. Those were intentionally not mixed into the recent feature/fix commits.

Use `git status --short` before any future commit and prefer `git commit --only <paths...>` if those release artifacts are still present.
