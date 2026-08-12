{
  description = "Nix flake for Routine, the calendar/tasks/notes desktop app";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Upstream ships an x86_64 AppImage only, so eachDefaultSystem would
      # advertise platforms that cannot possibly build.
      supportedSystems = [ "x86_64-linux" ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: import ./default.nix { inherit pkgs; });

      homeModules = {
        routine = import ./hm-module { inherit self; };
        default = self.homeModules.routine;
      };

      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);

      # `nix run .#update` -- refetch the rolling URL, re-hash, and rewrite
      # sources.json. Must be run from the flake root.
      apps = forAllSystems (pkgs: {
        update = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "routine-update";
              runtimeInputs = with pkgs; [
                nix
                jq
                coreutils
                gnused
                gawk
                binutils
                squashfsTools
              ];
              text = builtins.readFile ./update.sh;
            }
          }/bin/routine-update";
        };
      });
    };
}
