{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.ffnix;
in
{
  config = mkIf cfg.enable {
    boot.kernelModules = [ "batman_adv" ];

    boot.extraModulePackages = []
      ++ lib.optional (!cfg.batmanLegacy) config.boot.kernelPackages.batman_adv
      ++ lib.optional cfg.batmanLegacy (pkgs.batman-adv-legacy config.boot.kernelPackages);

    environment.systemPackages = []
      ++ lib.optional (!cfg.batmanLegacy) pkgs.batctl
      ++ lib.optional cfg.batmanLegacy pkgs.batctl-legacy;
  };
}
