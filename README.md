# ladybird-flake

A Nix flake for the [Ladybird](https://ladybird.org) browser. It packages the latest official [alpha release](https://github.com/LadybirdBrowser/ladybird/releases), and prebuilt binaries are available from a Cachix binary cache.

- **Always current:** a bot checks for new Ladybird releases every 12 hours and updates the flake automatically.
- **Always builds:** an update only lands on `main` after it has built successfully.
- **No multi-hour compile:** every build is pushed to [`sayidabyan.cachix.org`](https://sayidabyan.cachix.org).

> [!WARNING]
> Ladybird is alpha software. Expect missing features, rendering bugs and crashes. Don't use it for anything sensitive yet.

## Try it

```sh
nix run github:sayidabyan/ladybird-flake --accept-flake-config
```

`--accept-flake-config` lets Nix use the binary cache declared in this flake. Without it, Nix builds Ladybird from source, which takes a few hours. To avoid passing the flag every time, set up the cache permanently as described below.

## Set up the binary cache

Do this once, before installing.

**NixOS:**

```nix
nix.settings = {
  substituters = [ "https://sayidabyan.cachix.org" ];
  trusted-public-keys = [ "sayidabyan.cachix.org-1:AyabZhWClebxTMNzYHJNPX2gDpqxPErYrwCe+tGINC0=" ];
};
```

**Other Linux distributions:** if you have the `cachix` tool, run:

```sh
cachix use sayidabyan
```

Otherwise, add these lines to `/etc/nix/nix.conf` and restart the Nix daemon:

```
extra-substituters = https://sayidabyan.cachix.org
extra-trusted-public-keys = sayidabyan.cachix.org-1:AyabZhWClebxTMNzYHJNPX2gDpqxPErYrwCe+tGINC0=
```

## Install

### NixOS (flakes)

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ladybird.url = "github:sayidabyan/ladybird-flake";
  };

  outputs = { nixpkgs, ladybird, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        {
          environment.systemPackages = [ ladybird.packages.x86_64-linux.default ];
        }
      ];
    };
  };
}
```

### Home Manager

```nix
home.packages = [ inputs.ladybird.packages.x86_64-linux.default ];
```

### Overlay

The overlay replaces `pkgs.ladybird` with the version from this flake:

```nix
nixpkgs.overlays = [ inputs.ladybird.overlays.default ];
environment.systemPackages = [ pkgs.ladybird ];
```

> [!NOTE]
> Prebuilt binaries only match if you use this flake's own nixpkgs. That's what `packages.x86_64-linux.default` does. If you set `inputs.ladybird.inputs.nixpkgs.follows = "nixpkgs"` or use the overlay, Ladybird is built against *your* nixpkgs, and Nix will most likely build it from source.

### Imperative profile

```sh
nix profile install github:sayidabyan/ladybird-flake
```

## Updating

- **Flake:** run `nix flake update ladybird` in your own flake, then rebuild.
- **Profile:** find the entry name with `nix profile list`, then run `nix profile upgrade <name>`.

The package version matches the upstream release tag, e.g. `2026.47.7`. Release notes for each version are on [Ladybird's releases page](https://github.com/LadybirdBrowser/ladybird/releases).

## Supported platforms

| Platform | Status |
| --- | --- |
| `x86_64-linux` | Supported and cached |
| `aarch64-linux`, macOS | Not supported yet |

Cached binaries target the `x86-64-v2` baseline, so they run on any x86-64 CPU with SSE4.2 and POPCNT. That covers roughly every CPU from 2009 onwards.

## Troubleshooting

- **Nix is building Ladybird from source.** Check that the binary cache is set up (see above), that you aren't using `follows` or the overlay, and that you're on a commit of this flake that CI has finished building.
- **`ignoring untrusted flake configuration setting`.** Your user isn't trusted to add substituters. Either set up the cache system-wide as described above, or add yourself to `trusted-users`.
- **Something is broken in the browser itself.** Report it to [Ladybird upstream](https://github.com/LadybirdBrowser/ladybird/issues). Problems with the packaging belong in this repository's issues.

## How it works

Every 12 hours a GitHub Actions workflow checks for a new Ladybird release. When there is one, it builds the release, uploads the result to the binary cache, and merges the update into `main`. The pinned nixpkgs is updated weekly in the same way. If an update fails to build, an issue is opened, and `main` keeps the last version that built successfully.

## License

The Nix packaging in this repository is derived from [nixpkgs](https://github.com/NixOS/nixpkgs) and is MIT-licensed. Ladybird itself is [BSD-2-Clause](https://github.com/LadybirdBrowser/ladybird/blob/master/LICENSE).
