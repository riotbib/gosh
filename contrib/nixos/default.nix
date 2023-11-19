{ config, lib, pkgs, ... }:

with lib;

let
  
  # $ sudo nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
  nixpkgsUnstable = import <nixpkgs-unstable> { };

  gosh = nixpkgsUnstable.buildGo121Module {
    name = "gosh";

    src = pkgs.fetchFromGitHub {
      owner = "oxzi";
      repo = "gosh";
      rev = "a33a40e07dd3c3ce95613076c693331fe988e801";
      sha256 = "7NeUS952Of/ifjanckpIxKd02Jzja9Y3xu5jX86Ko6A=";
    };
    # TODO: One has to configure this one.
    vendorHash = "sha256-oR613uwIIo5DorSIU4BGH/C6R0scK/9S57RFfwF6iKY=";

    CGO_ENABLED = 0;
  };

  gosh-uid = 9001;

  mimeMap = pkgs.writeText "goshd-mimemap" (
    map (x: "${x.from} ${x.to}") cfg.mimeMap);

  cfg = config.services.gosh;

  goshConfig = pkgs.writeText "gosh.yml" ''
    ---
    
    user: "gosh"
    group: "gosh"
    
    store:
      path: "${cfg.dataDir}"
    
      id_generator:
        type: "random"
        length: 8
    
    webserver:
      listen:
        protocol: "tcp"
        bound: "${cfg.listenAddress}"
    
      protocol: "http"
    
      url_prefix: ""
    
      # custom_index: "/path/to/alternative/index.html"
    
      # static_files:
      #   "/favicon.ico":
      #     path: "/path/to/favicon.ico"
      #     mime: "image/vnd.microsoft.icon"
      #   "/custom.css":
      #     path: "/path/to/custom.css"
      #     mime: "text/css"
    
      item_config:
        max_size: "${cfg.maxFilesize}"
        max_lifetime: "${cfg.maxLifetime}"
    
        mime_drop:
          - "application/vnd.microsoft.portable-executable"
          - "application/x-msdownload"
        mime_map:
          "text/html": "text/plain"
    
      contact: "${cfg.contactMail}"
    '';
in {
  options.services.gosh = {
    enable = mkEnableOption "gosh, HTTP file server";

    contactMail = mkOption {
      type = types.str;
      description = "E-Mail address for abuses or the like.";
    };

    dataDir = mkOption {
      default = "/var/lib/gosh";
      type = types.path;
      description = "Directory for gosh's store.";
    };

    listenAddress = mkOption {
      default = ":8080";
      type = types.str;
      description = "Listen on a specific IP address and port.";
    };

    maxFilesize = mkOption {
      default = "10MiB";
      type = types.str;
      description = "Maximum file size for uploads.";
    };

    maxLifetime = mkOption {
      default = "24h";
      example = "2m";
      type = types.str;
      description = "Maximum lifetime for uploads.";
    };

    mimeMap = mkOption {
      default = [];
      example = [
        { from = "text/html"; to = "text/plain"; }
        { from = "image/gif"; to = "DROP"; }
      ];
      type = with types; listOf (submodule {
        options = {
          from = mkOption { type = str; };
          to   = mkOption { type = str; };
        };
      });
      description = "Map MIME types to others or DROP them.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ gosh ];

    systemd.services.gosh = {
      description = "gosh! Go Share";

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = ''
          ${gosh}/bin/gosh -config ${goshConfig} 
        '';

        User = "gosh";
        Group = "gosh";

        NoNewPrivileges = true;

        ProtectProc = "noaccess";
        ProcSubset = "pid";

        ProtectSystem = "full";
        ProtectHome = true;

        ReadOnlyPaths = "/";
        ReadWritePaths = "${cfg.dataDir}";
        InaccessiblePaths = "/boot /etc /mnt /root -/lost+found";
        NoExecPaths = "/";
        ExecPaths = "${gosh}/bin/gosh";

        PrivateTmp = true;
        PrivateDevices = true;
        PrivateIPC = true;

        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
      };
    };

    users.users.gosh = {
      group = "gosh";
      home = cfg.dataDir;
      createHome = true;
      uid = gosh-uid;
      isSystemUser = true;
    };

    users.groups.gosh.gid = gosh-uid;
  };
}
