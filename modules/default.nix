{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.ffnix;
  activeDomains = attrsets.filterAttrs (n: v: v.enable) cfg.domains;

  mkDomain = name: domCfg:
    let
      cidrToAddress = cidr: head (splitString "/" cidr);
      mkIfName = type:
        if type == "bridge" then "br-${name}" else
        if type == "batman" then "bat-${name}" else
        if type == "fastd" then "fd-${name}" else
        throw "unknown interface type ${type}, coud not generate name";
    in {
      #### NULL-ROUTES ####
      networks."10-lo" = {
        routes = if !domCfg.defaultNullRoute then [] else [
          {
            routeConfig = {
              Destination = "0.0.0.0/0";
              Metric = 200;
              Type = "unreachable";
              Table = domCfg.routingTable;
            };
          }
          {
            routeConfig = {
              Destination = "::/0";
              Metric = 200;
              Type = "unreachable";
              Table = domCfg.routingTable;
            };
          }
        ];
      };

      #### BRIDGE ####
      netdevs."30-${mkIfName "bridge"}".netdevConfig = {
        Name = mkIfName "bridge";
        Kind = "bridge";
      };
      networks."30-${mkIfName "bridge"}" = {
        matchConfig.Name = mkIfName "bridge";
        linkConfig = {
          RequiredForOnline = "no";
          MTUBytes = "${toString domCfg.mtu}";
        };
        address = domCfg.ipv4Addresses ++ domCfg.ipv6Addresses;
        routes = map (prefix: {
          routeConfig = {
            Destination = prefix;
            Scope = "link";
            Table = domCfg.routingTable;
          };
        }) (domCfg.ipv6Prefixes ++ [ domCfg.ipv4Prefix ]);
        routingPolicyRules = [
          {
            routingPolicyRuleConfig = {
              IncomingInterface = mkIfName "bridge";
              Table = domCfg.routingTable;
              Family = "both";
            };
          }
        ] ++ map (prefix: {
          routingPolicyRuleConfig = {
            From = prefix;
            Table = domCfg.routingTable;
          };
        }) (domCfg.ipv6Prefixes ++ [ domCfg.ipv4Prefix ]);
      };

      #### BATMAN ####
      netdevs."30-${mkIfName "batman"}" = mkIf (!cfg.batmanLegacy) {
        netdevConfig = {
          Kind = "batadv";
          Name = mkIfName "batman";
        };
        batmanAdvancedConfig = {
          GatewayMode = "server";
          RoutingAlgorithm = domCfg.batmanAlgorithm;
          OriginatorIntervalSec = 5;
        };
      };
      networks."30-${mkIfName "batman"}" = {
        matchConfig.Name = mkIfName "batman";
        bridge = [ "${mkIfName "bridge"}" ];
      };

      #### FASTD ####
      fdInstances."${mkIfName "fastd"}" = mkIf domCfg.tunnels.fastd.enable ({
        bind = mkDefault [ "any:${toString domCfg.tunnels.fastd.port}" ];
        mtu = domCfg.tunnels.fastd.mtu;
      } // domCfg.tunnels.fastd.extraConfig);
      links."30-${mkIfName "fastd"}" = mkIf domCfg.tunnels.fastd.enable {
        matchConfig.OriginalName = mkIfName "fastd";
        linkConfig.MACAddress = domCfg.tunnels.fastd.interfaceMac;
      };
      networks."30-${mkIfName "fastd"}" = mkIf (domCfg.tunnels.fastd.enable && !cfg.batmanLegacy) {
        matchConfig.Name = mkIfName "fastd";
        networkConfig.BatmanAdvanced = mkIfName "batman";
      };
      services."${mkIfName "batman"}" = mkIf (domCfg.tunnels.fastd.enable && cfg.batmanLegacy) {
        after = [ "fastd-${mkIfName "fastd"}.service" ];
        requiredBy = [ "fastd-${mkIfName "fastd"}.service" ];

        script = ''
          timeout 30 ${pkgs.bash}/bin/sh -c 'while ! ${pkgs.iproute2}/bin/ip link show dev ${mkIfName "fastd"} | grep UNKNOWN ; do sleep 1; done'
          ${pkgs.batctl-legacy}/bin/batctl -m ${mkIfName "batman"} interface add ${mkIfName "fastd"} || true
          ${pkgs.batctl-legacy}/bin/batctl -m ${mkIfName "batman"} gw_mode server || true
        '';

        serviceConfig =  {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      #### KEA / DHCPv4 ####
      keaInterfaces = if (domCfg.dhcpRange == "") then [] else [ "${mkIfName "bridge"}" ];
      keaSubnet4 = mkIf (domCfg.dhcpRange != "") ([ ({
        subnet = domCfg.ipv4Prefix;
        pools = [
          {
            pool = domCfg.dhcpRange;
          }
        ];
        option-data = [
          {
            name = "routers";
            data = cidrToAddress (head domCfg.ipv4Addresses);
          }
          {
            name = "domain-name-servers";
            data = cidrToAddress (head domCfg.ipv4Addresses);
          }
          {
            name = "domain-name";
            data = domCfg.searchDomain;
          }
        ];
      } // domCfg.dhcpExtraConfig) ]);

      #### RADVD ####
      radvdConfig = let
        radvdPrefixes = if domCfg.radvdPrefixes == [] then domCfg.ipv6Prefixes else domCfg.radvdPrefixes;
        mkPrefix = prefix: ''
          prefix ${prefix} { };
        '';
      in if (!domCfg.enableRadvd) then [] else [ ''
        interface ${mkIfName "bridge"} {
          IgnoreIfMissing on;
          AdvSendAdvert on;
          AdvLinkMTU ${toString domCfg.mtu};
          RDNSS ${cidrToAddress (head domCfg.ipv6Addresses)} { };
          DNSSL ${domCfg.searchDomain} { };

          ${concatStringsSep "\n" (map mkPrefix radvdPrefixes)}
        };
      '' ];
    };

    domConfigs = map (key: getAttr key (mapAttrs mkDomain activeDomains)) (attrNames activeDomains);
    mergedConfigs = mapAttrs (name: value: mkMerge value) (attrsets.zipAttrs (map (x: removeAttrs x [ ]) domConfigs));

in
{
  config = mkIf cfg.enable {
    systemd.network.netdevs = mergedConfigs.netdevs;
    systemd.network.networks = mergedConfigs.networks;
    systemd.network.links = mergedConfigs.links;

    systemd.services = mergedConfigs.services;

    ffnix.fastd.instances = mergedConfigs.fdInstances;

    services.kea.dhcp4 = mkIf (concatLists mergedConfigs.keaInterfaces.contents != []) {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = mergedConfigs.keaInterfaces;
        };
        subnet4 = mergedConfigs.keaSubnet4;
      };
    };

    services.radvd = mkIf (concatLists mergedConfigs.radvdConfig.contents != []) {
      enable = true;
      config = concatStringsSep "\n" (concatLists mergedConfigs.radvdConfig.contents);
    };
  };
}
