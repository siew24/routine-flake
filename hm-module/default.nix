{ self }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.routine;
in
{
  options.programs.routine = {
    enable = lib.mkEnableOption "Routine, the calendar/tasks/notes app";

    package = lib.mkOption {
      type = lib.types.package;
      # Built from the *consuming* configuration's pkgs so that its
      # nixpkgs.config applies -- Routine is unfree, and referring to
      # self.packages.${system} instead would evaluate against this flake's own
      # unconfigured legacyPackages and fail the allowUnfree check.
      default = (import "${self}/default.nix" { inherit pkgs; }).routine;
      defaultText = lib.literalExpression "routine built from the host's pkgs";
      description = "The Routine package to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
