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
    bird = {
      enable = mkEnableOption "bird routing daemon";
      routerID = mkOption {
        type = types.str;
      };
      kernelTable = mkOption {
        type= types.int;
      };
      earlyExtraConfig = mkOption {
        type = types.lines;
        default = "";
      };
      extraConfig = mkOption {
        type = types.lines;
        default = "";
      };
  };

  };

  config = mkIf cfg.enable {
    services.vnstat.enable = true;

    programs.mtr.enable = true;
  };

  imports = [
    ./modules/batman.nix
    ./modules/fastd.nix
    ./modules/bird
  ];
}
