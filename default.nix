{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.ffnix;
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
          enable = mkEnableOption "ffnix Domain";
          ipv4Prefix = mkOption {
            type = types.str;
          };
          ipv6Prefixes = mkOption {
            type = types.listOf types.str;
          };
          ipv4Addresses = mkOption {
            type = types.listOf types.str;
            description = ''
              IPv4 Addresses to be configured on the bridge interface.
              WARNING: the primary-ipv4-address to be send as a gateway address via DHCP has to be the first one.
            '';
          };
          ipv6Addresses = mkOption {
            type = types.listOf types.str;
            description = ''
              IPv6 Addresses to be configured on the bridge interface.
            '';
          };
          routingTable = mkOption {
            type = types.int;
          };
          defaultNullRoute = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Create a Null-Route in the routing-table to allow traffic leaks on the gateways default route when uplink is down.
              The first address will be sen't as the DNS-Server via RAs.
            '';
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
          searchDomain = mkOption {
            type = types.str;
          };
          dhcpExtraConfig = mkOption {
            description = ''
              Additional config that will me merged with the kea-subnet4 config
            '';
            default = {};
            type = (pkgs.formats.json {}).type;
          };
          batmanAlgorithm = mkOption {
            default = "batman-iv";
            type = types.str;
          };
          tunnels = mkOption {
            default = {};
            type = types.submodule {
              options = {
                fastd = mkOption {
                  default = {};
                  type = types.submodule {
                    options = {
                      enable = mkEnableOption "Fastd Tunnel";
                      mtu = mkOption {
                        type = types.int;
                        default = 1406;
                      };
                      port = mkOption {
                        type = types.int;
                        default = 10000;
                      };
                      interfaceMac = mkOption {
                        type = types.str;
                      };
                      extraConfig = mkOption {
                        description = ''
                          Additional config that will me merged with the fastd-instance config
                        '';
                        default = {};
                        type = (pkgs.formats.json {}).type;
                      };
                    };
                  };
                };
              };
            };
          };
        };
      });
    };
  };

  config = mkIf cfg.enable {
    services.vnstat.enable = true;

    programs.mtr.enable = true;

  };

  imports = [
    ./modules
    ./modules/batman.nix
    ./modules/fastd.nix
    ./modules/bird
  ];
}
