{
  pkgs ? import <nixpkgs> { },
  system ? pkgs.stdenv.hostPlatform.system,
}:
let
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  variant =
    sources.${system}
      or (throw "routine: unsupported system '${system}', sources.json has: ${
        builtins.concatStringsSep ", " (builtins.attrNames sources)
      }");
in
rec {
  routine = pkgs.callPackage ./package.nix { inherit variant; };
  default = routine;
}
