{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.ffnix;
in
{
  options.ffnix = {
    enable = mkEnableOption "ffnix";
    batman-legacy = mkEnableOption "batman-adv-legacy";
  };

  config = mkIf cfg.enable {
    services.vnstat.enable = true;

    programs.mtr.enable = true;
  };

  imports = [
    ./modules/batman.nix
  ];
}
