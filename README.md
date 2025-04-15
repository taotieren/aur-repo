# [PKGBUILDs](https://wiki.archlinux.org/index.php/PKGBUILD) for [Arch User Repository](https://aur.archlinux.org)

This repository contains the packages I maintain in [AUR](https://aur.archlinux.org/packages?K=taotieren&SeB=M), checked into git as subtrees for easier management and pull requests.

Powered by [lilac](https://github.com/archlinuxcn/lilac).

[![Maintainer](https://img.shields.io/static/v1?label=maintainer&message=taotieren&color=097788)](https://aur.archlinux.org/account/taotieren)

[![Packaging consistency check](https://github.com/taotieren/aur-repo/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/taotieren/aur-repo/actions/workflows/test.yml)

<a href="https://http3.wcode.net/?q=aur-repo.taotieren.com" target="_blank">
    <img src="https://http3.wcode.net/badges/http3.svg?host=aur-repo.taotieren.com" alt="" style="max-width: 100%; height: 24px;"/>
</a>

## Pre-built AUR packages (experimental)

Pre-built versions of the AUR packages are also available.

Add the following lines to `/etc/pacman.conf`:

```ini
[aur-repo]
## China Telecom Network (100Mbps) (ipv4, ipv6, http, https)
Server = https://fun.ie8.pub:2443/aur-repo/$arch
```

```ini
[aur-repo]
## CloudFlare Preferred CDN (ipv4, ipv6, http, https)
Server = https://mirrors.kicad.online/aur-repo/$arch
```

```ini
[aur-repo]
## CloudFlare Free CDN (ipv4, ipv6, http, https)
Server = https://aur-repo.taotieren.com/aur-repo/$arch
```

## [aur-repo-mirrorlist](https://github.com/taotieren/repo-misc-tools/tree/main/mirrorlist)

```bash
pacman -Syu aur-repo-mirrorlist-git
```

```ini
[aur-repo]
Include = /etc/pacman.d/aur-repo-mirrorlist
```

Add and trust my GPG key in pacman keyring:

```bash
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
```

## [devtools-aur-repo](https://github.com/taotieren/repo-misc-tools/tree/main/devtools-aur-repo)

```bash
pacman -Syu devtools-aur-repo-git
```

## rsync

```bash
## Only IPv6
## Status: OK
rsync rsync://aur-repo.taotieren.com
rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo.taotieren.com/aur-repo /opt/sync/aur-repo

## Only IPv4
## Status: OK
# rsync rsync://aur-repo.taotieren.com
# rsync -avzP --bwlimit=30720 --timeout=120 --contimeout=120  --exclude-from=/opt/rsync/exclude.list rsync://aur-repo.taotieren.com/aur-repo /opt/sync/aur-repo
```
