# [PKGBUILDs](https://wiki.archlinux.org/index.php/PKGBUILD) for [Arch User Repository](https://aur.archlinux.org)

This repository contains the packages I maintain in [AUR](https://aur.archlinux.org/packages?K=taotieren&SeB=M), checked into git as subtrees for easier management and pull requests.

Powered by [lilac](https://github.com/archlinuxcn/lilac).

[![Maintainer](https://img.shields.io/static/v1?label=maintainer&message=taotieren&color=097788)](https://aur.archlinux.org/account/taotieren)

## Pre-built AUR packages (experimental)

Pre-built versions of the AUR packages are also available.

Add the following lines to `/etc/pacman.conf`:

```ini
[aur-repo]
Server = https://aur-repo.taotieren.com/$arch
```

Add and trust my GPG key in pacman keyring:

```bash
sudo pacman-key --recv-keys FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
sudo pacman-key --lsign-key FEB77F0A6AB274FB0F0E5947B327911EA9E522AC
```
