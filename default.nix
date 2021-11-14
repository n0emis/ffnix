{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.ffnix;
in
{
  options.ffnix = {
    enable = mkEnableOption "ffnix";
    batman-legacy = mkOption {
      default = false;
      example = true;
      type = types.bool;
      description = ''
        Use batman-adv-legacy - do not use in new communities!
      '';
    };
  };

  config = mkIf cfg.enable {
    services.vnstat.enable = true;

    programs.mtr.enable = true;
  };

  imports = [
    ./modules/batman.nix
    ./modules/fastd.nix
  ];
}
