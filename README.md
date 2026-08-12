# routine-flake

Nix flake packaging [Routine](https://routine.co) for Linux, built from
upstream's AppImage.

Routine is proprietary (free tier plus paid plans), so the package is marked
`license = lib.licenses.unfree` and you need `allowUnfree` to build it.

## Use

```nix
{
  inputs.routine = {
    url = "github:siew24/routine-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Either take the package directly:

```nix
environment.systemPackages = [ inputs.routine.packages.x86_64-linux.routine ];
```

or use the home-manager module:

```nix
{ routine, ... }:
{
  imports = [ routine.homeModules.default ];
  programs.routine.enable = true;
}
```

`x86_64-linux` only — upstream ships no other Linux build.

## Updating

Upstream has no releases feed and no versioned URL: there is one unversioned
AppImage at `releases.routine.co` that changes underneath you. So updating means
fetching it, hashing it, and reading the version out of the image.

```console
$ nix run .#update      # rewrites sources.json; run from the flake root
```

A GitHub Actions workflow does this daily and commits when the hash changes.

## Notes on the packaging

Two things here are not boilerplate, and both are load-bearing:

**Upstream's `AppRun` is an installer, not a launcher.** It copies the AppImage
into `~/.local/bin`, writes a desktop entry, and on later runs copies itself
over whatever path that entry's `Exec=` names — i.e. it self-updates in place.
None of that can work from an immutable store path, so `postExtract` replaces it
with a plain `exec` of the real binary.

**`Intl.DateTimeFormat().resolvedOptions().timeZone` returns `undefined` on
NixOS.** Chromium's ICU derives the zone by matching `/etc/localtime` against a
known zoneinfo prefix; on NixOS that symlink resolves into
`/nix/store/…-tzdata-…/share/zoneinfo/…`, which ICU doesn't recognise. Routine
passes that value straight into a string encoder while its controller bundle is
loading, which throws and leaves the window **blank white**. The launcher
derives the zone from `/etc/localtime` and exports `TZ` before starting the app.

The second one is arguably an upstream bug — Routine should tolerate an
undefined `timeZone` — but it needs handling here regardless.
