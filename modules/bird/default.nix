{ config, lib, pkgs, ... }:

with import ../common-vars.nix { inherit lib config; };

let
  cfg = config.ffnix.bird;
in {
  config = lib.mkIf cfg.enable {
    services.bird2.enable = true;
    environment.etc."bird/bird2.conf".source = lib.mkForce (pkgs.substituteAll {
      name = "bird2-${config.networking.hostName}.conf";

      inherit (cfg) routerID kernelTable;

      # the check is run in a sandboxed nix derivation and does not have access to password includes
      checkPhase = ''
        cat $out | sed 's/include.*//g' > temp.conf
        echo $out
        ${pkgs.bird2}/bin/bird -d -p -c temp.conf
      '';

      src = pkgs.writeText "bird2-${config.networking.hostName}-template.conf" ''
        ${cfg.earlyExtraConfig}
        ${lib.fileContents ./bird2.conf}
        ${cfg.extraConfig}
      '';
    });
  };
}
