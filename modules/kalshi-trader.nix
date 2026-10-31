{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kalshi-trader;
  stateDir = "/var/lib/kalshi-trader";

  # Shared by the service and the CLI so both use the same settings and database.
  environment = {
    KT_CONFIG_PATH = "${cfg.configFile}";
    KT_DB_PATH = "${stateDir}/kalshi_trader.db";
    KT_LOG_DIR = "${stateDir}/logs";
    KT_DASHBOARD__PORT = toString cfg.port;
  };

  # `kalshi-trader status`, `trading pause`, `backtest ...` act on the service's database,
  # so they re-run themselves as the service user.
  cli = pkgs.writeShellScriptBin "kalshi-trader" ''
    if [ "$(id -un)" != kalshi-trader ]; then
      exec ${config.security.wrapperDir}/sudo -u kalshi-trader "$0" "$@"
    fi
    ${lib.toShellVars environment}
    export ${lib.concatStringsSep " " (lib.attrNames environment)}
    exec ${lib.getExe cfg.package} "$@"
  '';
in {
  options.services.kalshi-trader = {
    enable = lib.mkEnableOption "the kalshi-trader tennis research and paper-trading engine (it never places real orders)";

    package = lib.mkPackageOption pkgs "kalshi-trader" {};

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = ''
        Dashboard port on 127.0.0.1. The dashboard has no login, so share it with
        Tailscale Serve instead of opening it in the firewall.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = "${cfg.package}/share/kalshi-trader/settings.toml";
      defaultText = lib.literalExpression ''"''${config.services.kalshi-trader.package}/share/kalshi-trader/settings.toml"'';
      description = ''
        Non-secret settings: risk limits, strategy thresholds, bankroll and so on. Defaults to
        the project's config/settings.toml. The module overrides its db_path and log_dir
        (both move to ${stateDir}) and its dashboard port.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/kalshi-trader.env";
      description = ''
        Optional file of KT_* variables kept out of the Nix store, for example
        KT_KALSHI__API_KEY_ID and KT_KALSHI__PRIVATE_KEY_PATH (an absolute path readable by
        the kalshi-trader user). Credentials are only needed for the WebSocket order-book
        feed; without them the engine polls public REST data. Use a read-only key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.kalshi-trader = {
      isSystemUser = true;
      group = "kalshi-trader";
    };
    users.groups.kalshi-trader = {};

    environment.systemPackages = [cli];

    systemd.services.kalshi-trader = {
      description = "Kalshi tennis research engine (paper trading only, no real orders)";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      inherit environment;

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} run";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        User = "kalshi-trader";
        Group = "kalshi-trader";
        StateDirectory = "kalshi-trader";
        StateDirectoryMode = "0750";
        WorkingDirectory = stateDir;
        Restart = "on-failure";
        RestartSec = 15;
        # SIGTERM stops the engine gracefully: recordings are flushed and equity is snapshotted.
        TimeoutStopSec = 45;

        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
