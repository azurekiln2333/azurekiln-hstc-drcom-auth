# OpenWrt LuCI package

This directory contains a LuCI app for configuring the HSTC Dr.COM authentication scripts.

## Build with OpenWrt SDK

Copy or symlink the package into an OpenWrt SDK package directory:

```sh
cp -r openwrt/luci-app-drcom-auth /path/to/openwrt-sdk/package/
cd /path/to/openwrt-sdk
./scripts/feeds update luci
./scripts/feeds install luci-base
make menuconfig
make package/luci-app-drcom-auth/compile V=s
```

Install the generated `luci-app-drcom-auth` package on the router, then open:

```text
LuCI -> Services -> Dr.COM Auth
```

Enable the init service once if you want it to run after reboot:

```sh
/etc/init.d/drcom_auth enable
```

The web page writes `/etc/config/drcom_auth`. The init script renders that UCI config to `/usr/share/drcom-auth/config.sh` so the original shell workflow can keep using the same variables.
