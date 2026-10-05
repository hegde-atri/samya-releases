# Samaya releases

Prebuilt binaries of [Samaya](https://git.hegdeatri.com/hegdeatri/samaya), a
calm, local-first daily planner over your own Org files.

Each [release](https://git.hegdeatri.com/hegdeatri/samaya-releases/releases)
has a `samaya-X.Y.Z-x86_64-linux.tar.gz` with the `samaya` binary, its
`.desktop` entry and icon, and a SHA-256 checksum beside it.

## Install

On x86_64 Linux with glibc 2.36 or newer (Debian 12, Ubuntu 22.04, Fedora,
Arch and the like):

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh
```

This installs `samaya`, its menu entry and its icon into `~/.local`, after
checking the archive's checksum. Run it again to upgrade, or pass a version to
pin one:

```sh
curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh -s -- v0.1.0
```

On NixOS the binary does not find its libraries by itself; enable
`programs.nix-ld` with `wayland`, `libxkbcommon`, `vulkan-loader` and `libGL`
in `programs.nix-ld.libraries`.

Releases are published automatically when a version is tagged; this repository
holds no source code.
