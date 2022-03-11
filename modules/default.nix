{ pkgs, config, lib, ... }:

with lib;

let
  cfg = config.ffnix;
  activeDomains = attrsets.filterAttrs (n: v: v.enable) cfg.domains;

  mkDomain = name: domCfg:
    let
      mkIfName = type:
        if type == "bridge" then "br-${name}" else
        if type == "batman" then "bat-${name}" else
        throw "unknown interface type ${type}, coud not generate name";
    in {
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

      netdevs."30-${mkIfName "bridge"}".netdevConfig = {
        Name = mkIfName "bridge";
        Kind = "bridge";
      };
      networks."30-${mkIfName "bridge"}" = {
        matchConfig.Name = mkIfName "bridge";
        linkConfig.RequiredForOnline = "no";
        address = domCfg.addresses;
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
    };

    domConfigs = map (key: getAttr key (mapAttrs mkDomain activeDomains)) (attrNames activeDomains);
    mergedConfigs = mapAttrs (name: value: mkMerge value) (attrsets.zipAttrs (map (x: removeAttrs x [ "foo" ]) domConfigs));

in
{
  config = mkIf cfg.enable {
    environment.etc."ffnix.json".source = pkgs.writeText "ffnix.json" (generators.toJSON {} activeDomains);
    systemd.network.netdevs = mergedConfigs.netdevs;
    systemd.network.networks = mergedConfigs.networks;
  };
}
