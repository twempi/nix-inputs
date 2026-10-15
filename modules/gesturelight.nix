{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gesturelight;

  configuredUrl =
    if cfg.url == null
    then null
    else if lib.hasPrefix "http://" cfg.url
    then cfg.url
    else "http://${cfg.url}";

  # The base package with the ESP32 address baked in, so launching the app from
  # the desktop menu needs no extra flags.
  configuredPackage =
    pkgs.runCommand "gesturelight-configured" {
      nativeBuildInputs = [pkgs.makeWrapper];
    } ''
      mkdir -p "$out/bin" "$out/share/applications"
      makeWrapper ${cfg.package}/bin/gesturelight-hand-tracker \
        "$out/bin/gesturelight-hand-tracker" \
        --set GESTURELIGHT_ESP32_URL ${lib.escapeShellArg configuredUrl}
      cp ${cfg.package}/share/applications/gesturelight.desktop \
        "$out/share/applications/gesturelight.desktop"
      substituteInPlace "$out/share/applications/gesturelight.desktop" \
        --replace-fail ${lib.escapeShellArg "${cfg.package}/bin/gesturelight-hand-tracker"} \
        "$out/bin/gesturelight-hand-tracker"
    '';
in {
  options.gesturelight = {
    enable = lib.mkEnableOption "GestureLight webcam lamp control";

    package = lib.mkPackageOption pkgs "gesturelight" {};

    url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "192.168.1.50";
      description = ''
        ESP32 IP address or hostname, optionally with a port. The module
        adds the required http:// prefix when it is omitted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.url != null && cfg.url != "";
        message = "gesturelight.url must be set when gesturelight.enable is true.";
      }
    ];

    environment.systemPackages =
      lib.optional (cfg.url != null && cfg.url != "") configuredPackage;
  };
}
