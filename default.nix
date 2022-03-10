{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.ffnix;
  activeDomains = attrsets.filterAttrs (n: v: v.enable) cfg.domains;
in
{
  options.ffnix = {
    enable = mkEnableOption "ffnix";
    batmanLegacy = mkOption {
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
    domains = mkOption {
      description = "Freifunk Domains (a domain is a seperated L2 network segment)";
      default = {};
      type = with types; attrsOf (submodule {
        options = {
          enable = mkEnableOption "ffnix Site";
          ipv4Prefix = mkOption {
            type = types.str;
          };
          ipv6Prefixes = mkOption {
            type = types.listOf types.str;
          };
          addresses = mkOption {
            type = types.listOf types.str;
          };
          routingTable = mkOption {
            type = types.int;
          };
          mtu = mkOption {
            type = types.int;
          };
          enableRadvd = mkOption {
            default = false;
            type = types.bool;
          };
          radvdPrefixes = mkOption {
            default = [];
            type = types.listOf types.str;
          };
          dhcpRange = mkOption {
            default = "";
            type = types.str;
          };
          searchDomains = mkOption {
            default = [];
            type = types.listOf types.str;
          };
          tunnels = mkOption {
            default = {};
            type = (pkgs.formats.json {}).type;
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    services.vnstat.enable = true;

    programs.mtr.enable = true;

    environment.etc."ffnix.json".source = pkgs.writeText "ffnix.json" (generators.toJSON {} activeDomains);
  };

  imports = [
    ./modules/batman.nix
    ./modules/fastd.nix
    ./modules/bird
  ];
}
