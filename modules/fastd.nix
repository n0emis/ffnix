# Heavily inspired by https://git.petabyte.dev/petabyteboy/freifunk-nixfiles/src/branch/master/fastd.nix

{ config, pkgs, lib, ...}:

with lib;

let
  cfg = config.ffnix.fastd;

  toYesNo = b: if b then "yes" else "no";

  createDir = name:
    runCommand name
      { passAsFile = [ "text" ];
        # Pointless to do this on a remote machine.
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        mkdir -p "$out/"
      '';

  peerOpts = { ... }: {
    options = {

      name = mkOption {
        type = types.str;
      };

      remotes = mkOption {
        default = [];
        example = [ "[2001:db8::1]:10000" ''ipv4 "fastd.example.com" port 10000'' ];
        type = with types; listOf str;
      };

      publicKey = mkOption {
        default = null;
        example = "8208b2f0efa580e4115ee4fcf7b1a64d85fa68dc9ef1a6072f6f4e712b542b2c";
        type = with types; nullOr str;
        description = ''
          Private key
        '';
      };

      float = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Allows this peer to connect from other IPs
        '';
      };
    };
  };

  instanceOpts = { ... }: {
    options = {
      privateKeyFile = mkOption {
        default = null;
        example = "/private/fastd_key";
        type = with types; nullOr str;
        description = ''
          Path to file containing private key
        '';
      };

      privateKey = mkOption {
        default = null;
        example = "907f458e1c0577023845122df678281994e9642a5f5ff4126546479f5fa64e74";
        type = with types; nullOr str;
        description = ''
          Private key
        '';
      };

      peerLimit = mkOption {
        default = 300;
        example = 20;
        type = types.int;
        description = ''
          Maximum number of peers
        '';
      };

      mode = mkOption {
        default = "tap";
        type = types.enum [ "tun" "tap" ];
        description = ''
          Mode of operation: tun (layer 3) or tap (layer 2)
        '';
      };

      mtu = mkOption {
        default = 1406;
        example = 1280;
        type = types.int;
        description = ''
          Maximum transmission unit
        '';
      };

      methods = mkOption {
        default = [
          "null+salsa2012+umac"
          "salsa2012+umac"
          "null"
        ];
        example = [ "aes128-ctr+umac" ];
        type = with types; listOf str;
        description = ''
          Encrpytion and authentication ciphers offered to connecting peers
        '';
      };

      bind = mkOption {
        default = [ "any:10000 default ipv4" ];
        example = [ "10.0.0.1:7777" "[fda0::1]:7777" ];
        type = with types; listOf str;
        description = ''
          IPs and ports to bind to
        '';
      };

      statusSocket = mkOption {
        default = null;
        example = "/run/fastd.sock";
        type = with types; nullOr str;
        description = ''
          Status socket
        '';
      };

      blacklistedKeys = mkOption {
        default = null;
        example = ''
          71c926485be08ac0ddc9783cec0487a9f5d4211fae634f9b7467030161b05409
          6250851453f34ec4520dcdf3ae3aa4d0d62fad0c6f573d5e7a78b0a8359dc6ea
        '';
        type = with types; nullOr lines;
        description = ''
          If specified, incoming connections will be accepted, unless their public key is in the blacklist.
          Otherwise, unknown peers will be rejected.
          Mutually exclusive with verifyScript.
        '';
      };

      verifyScript = mkOption {
        default = null;
        example = ''
          #!${pkgs.stdenv.shell}
          PEER_KEY=$1
          echo peer "$PEER_KEY" joining
          exit 0
        '';
        type = with types; nullOr str;
        description = ''
          If specified, incoming connections will be accepted, if this custom verify script returns a 0 exit code.
          Otherwise, unknown peers will be rejected.
          Mutually exclusive with blacklistedKeys.
        '';
      };

      peersDir = mkOption {
        default = null;
        example = "/path/to/fastd/peers/";
        type = with types; nullOr str;
      };

      peers = mkOption {
        default = [];
        example = [
          {
            name = "server01";
            publicKey = "8208b2f0efa580e4115ee4fcf7b1a64d85fa68dc9ef1a6072f6f4e712b542b2c";
            remotes = [ "ipv4 example.org:10000" ];
          }
        ];
        type = with types; listOf (submodule peerOpts);
      };

      logLevel = mkOption {
        default = "verbose";
        type = types.enum [ "fatal" "error" "warn" "info" "verbose" "debug" "debug2" ];
      };

      hideIPAddresses = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Hide sensitive data in logs
        '';
      };

      packetMark = mkOption {
        default = null;
        example = "0x42";
        type = with types; nullOr str;
      };

      package = mkOption {
        default = pkgs.fastd;
        type = types.package;
      };

      extraConfig = mkOption {
        default = "";
        type = types.lines;
      };

    };
  };

  generateUnit = name: values:
    # exactly one way to specify the private key must be set
    assert (values.privateKey != null) != (values.privateKeyFile != null);
    assert (values.blacklistedKeys == null) || (values.verifyScript == null);
    # TODO: more asserts
    let
      privKey = if (values.privateKeyFile != null) then values.privateKeyFile else pkgs.writeText "fastd-key-${name}" ''secret "${values.privateKey}";'';

      dummyDir = if (values.peersDir == null && values.peers == {}) then createDir "fastd-dummy-peers-${name}" else null;

      blacklist = if (values.blacklistedKeys == null) then null else pkgs.writeText "fastd-blacklist-${name}" values.blacklistedKeys;

      verifyScript = if (values.verifyScript != null) then pkgs.writeScript "fastd-verify-${name}.sh"
        else if (values.blacklistedKeys != null) then pkgs.writeScript "fastd-verify-${name}.sh" ''
          #!${pkgs.stdenv.shell}
          PEER_KEY=$1
          echo peer "$PEER_KEY" joining
          if /bin/grep -Fq $PEER_KEY ${blacklist}; then
          exit 1
          else
          exit 0
          fi
        '' else null;

      cfgFile = pkgs.writeText "fastd-cfg-${name}" ''
        interface "${name}";
        mode ${values.mode};
        mtu ${toString values.mtu};
        peer limit ${toString values.peerLimit};
        log to syslog level ${values.logLevel};
        hide ip addresses ${toYesNo values.hideIPAddresses};
        include "${privKey}";

        ${optionalString (values.statusSocket != null) ''
          status socket "${values.statusSocket}";
        ''}

        ${concatMapStringsSep "\n" (bind: ''
          bind ${bind};
        '') values.bind}

        ${concatMapStringsSep "\n" (method: ''
          method "${method}";
        '') values.methods}

        ${optionalString (values.peersDir != null) ''
          include peers from "${values.peersDir}";
        ''}

        ${optionalString (values.peers != {}) concatMapStringsSep "\n" (peer: ''
          peer "${peer.name}" {
            key "${peer.publicKey}";
            float ${toYesNo peer.float};
            ${concatMapStringsSep "\n" (remote: ''
              remote ${remote};
            '') peer.remotes}
          }
        '') values.peers}

        ${optionalString (values.peersDir == null && values.peers == {}) ''
          include peers from "${dummyDir}";
        ''}

        ${optionalString (verifyScript != null) ''
          on verify "${verifyScript} $PEER_KEY";
        ''}

        ${optionalString (values.packetMark != null) ''
          packet mark ${values.packetMark};
        ''}

        ${values.extraConfig}
      '';

    in nameValuePair "fastd-${name}" {
      description = "fastd instance - ${name}";
      requires = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${values.package}/bin/fastd -c ${cfgFile}";
        ExecReload = "/bin/kill -HUP $MAINPID";
        Restart = "always";
        RestartSec = "10s";
        User = cfg.user;
        Group = "nogroup";
        AmbientCapabilities  = "CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW";
      };
      unitConfig = {
        StartLimitInterval = "1min";
      };
    };
in {

  options =  {
    ffnix.fastd = {
      instances = mkOption {
        description = "fastd instances";
        default = {};
        example = {
          my-fastd = {
            privateKey = "907f458e1c0577023845122df678281994e9642a5f5ff4126546479f5fa64e74";
            peers = [
              {
                name = "server01";
                publicKey = "8208b2f0efa580e4115ee4fcf7b1a64d85fa68dc9ef1a6072f6f4e712b542b2c";
                remotes = [ "ipv4 example.org:10000" ];
              }
            ];
          };
        };
        type = with types; attrsOf (submodule instanceOpts);
      };

      user = mkOption {
        default = "fastd";
        type = types.str;
      };

    };
  };

  config = mkIf (cfg.instances != {}) {
    users.users = optionalAttrs (cfg.user == "fastd") ({
        fastd = {
          name = "fastd";
          group = "nogroup";
          isSystemUser = true;
        };
      }
    );

    systemd.services = mapAttrs' generateUnit cfg.instances;
  };
}
