# Samaya releases

Prebuilt binaries of Samaya, a calm daily planner over plain Org files.
Everything stays in plain text files in a folder you choose, which open in
Emacs too. There is no account and no server.

## Install

On 64-bit Linux: Ubuntu 22.04, Debian 12, Fedora, Arch, or anything newer.

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh
```

This checks the download's checksum, then puts `samaya` in `~/.local/bin` and
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

Calendars and GitHub are optional. Connecting a Google or Outlook calendar
needs your own OAuth client or app registration, so skip them for a first try.

## Upgrade and uninstall

Run the install command again to upgrade. To uninstall:

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

Each [release](https://git.hegdeatri.com/hegdeatri/samaya-releases/releases)
lists what changed and has a `samaya-X.Y.Z-x86_64-linux.tar.gz` holding the
`samaya` binary, its `.desktop` entry and icon, with a SHA-256 checksum beside
it. Releases are published automatically when a version is tagged; this
repository holds no source code.
