{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.ffnix;
in
{
  config = mkIf cfg.enable {
    boot.kernelModules = [ "batman_adv" ];

    boot.extraModulePackages = []
      ++ lib.optional (!cfg.batman-legacy) config.boot.kernelPackages.batman_adv
      ++ lib.optional cfg.batman-legacy (pkgs.batman-adv-legacy config.boot.kernelPackages);

    environment.systemPackages = []
      ++ lib.optional (!cfg.batman-legacy) pkgs.batctl
      ++ lib.optional cfg.batman-legacy pkgs.batctl-legacy;
  };
}
