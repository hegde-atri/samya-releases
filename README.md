# Samaya releases

Prebuilt binaries of Samaya, a calm daily planner over plain Org files.
Everything stays in plain text files in a folder you choose, which open in
Emacs too. There is no account and no server.

## Install

On 64-bit Linux: Ubuntu 22.04, Debian 12, Fedora, Arch, or anything newer.

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh
```

This checks the download's checksum, and its signature if
[minisign](https://jedisct1.github.io/minisign/) is installed, then puts
`samaya` in `~/.local/bin` and
adds it to your app menu. If the installer says `~/.local/bin` is not on your
`PATH`, open Samaya from the app menu or run `~/.local/bin/samaya`.

To install a particular version, pass it on:

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh -s -- v0.1.0
```

## First run

1. Make a folder for your tasks, such as `~/org`. An empty one is fine.
2. In Samaya, open **Settings → Org files** and choose that folder. Each `.org`
   file in it is a channel, such as `work.org` or `health.org`; you can create
   channels from the app.
3. Plan tasks in **Today** and **Week**, then try **Focus** on one of them.

Calendars and the GitHub, Forgejo and Azure DevOps panels are optional.
Connecting a Google or Outlook calendar needs your own OAuth client or app
registration, so skip them for a first try.

## Noctalia integration

For native Noctalia 5.3.0, this repository is also a public plugin source.
Install a GUI build of Samaya 1.12.0 or later separately, and make sure
`samaya` is on Noctalia's `PATH`.

1. Open **Noctalia Settings → Plugins → Add source**.
2. Choose **Git**, name it `samaya`, and use
   `https://git.hegdeatri.com/hegdeatri/samaya-releases`.
3. Enable **Samaya**, then add its **Focus** widget through your bar's
   **Add widget** picker.

The widget shows your Focus clock and meetings, with a panel for Focus,
meeting Join, task capture and calendar sync. No local checkout or TOML
editing is required. See the [plugin guide](samaya/README.org) for settings,
CLI installation, troubleshooting and removal.

Plugin updates are published with Samaya releases. Noctalia's **Auto-update
plugins → All sources** setting includes this custom Git source; otherwise
use its **Update** action. Plugin updates and desktop app updates are separate.

## Upgrade and uninstall

Samaya checks for a new version once a day; **Settings → Update available**
updates it in place, once the release's signature checks out. Running the
install command again upgrades too. To uninstall:

```sh
rm ~/.local/bin/samaya ~/.local/share/applications/samaya.desktop \
  ~/.local/share/icons/hicolor/128x128/apps/samaya.png
```

Your Org folder is never touched.

## NixOS

The prebuilt binary does not find its graphics libraries on NixOS by itself.
Enable `programs.nix-ld` and add `wayland`, `libxkbcommon`, `vulkan-loader`
and `libGL` to `programs.nix-ld.libraries`.

## Releases

What changed in each version is in [CHANGELOG.org](CHANGELOG.org), and in
Samaya itself under **Settings → Changelog**.

Each [release](https://git.hegdeatri.com/hegdeatri/samaya-releases/releases)
lists what changed and has a `samaya-X.Y.Z-x86_64-linux.tar.gz` holding the
`samaya` binary, its `.desktop` entry and icon, with a SHA-256 checksum and,
from 1.8.0, a minisign signature beside it. Releases are published
automatically when a version is tagged. This repository also holds the
Noctalia plugin source and catalog used by Noctalia's plugin manager.

## Verifying a release

Releases are signed with this key, also in [minisign.pub](minisign.pub):

```
RWReXZNuxj5aplTyPD4awKxzs/sL9nlCssugg1Cd9ZbRWrwksTyfsJNe
```

```sh
minisign -V -P RWReXZNuxj5aplTyPD4awKxzs/sL9nlCssugg1Cd9ZbRWrwksTyfsJNe \
  -m samaya-X.Y.Z-x86_64-linux.tar.gz
```

The trusted comment it prints is the archive's file name.
