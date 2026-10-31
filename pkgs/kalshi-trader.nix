{
  pkgs,
  lib,
  src,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}: let
  # The interpreter kalshi-trader's own dev shell and tests use.
  python = pkgs.python313;

  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = src;};

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {inherit python;}).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
    ]);

  inherit (pkgs.callPackages pyproject-nix.build.util {}) mkApplication;
in
  (mkApplication {
    venv = pythonSet.mkVirtualEnv "kalshi-trader-env" workspace.deps.default;
    package = pythonSet.kalshi-trader;
  }).overrideAttrs (old: {
    # The default settings live outside the Python package; the NixOS module reads them here.
    postInstall =
      (old.postInstall or "")
      + ''
        install -Dm444 ${src}/config/settings.toml "$out/share/kalshi-trader/settings.toml"
      '';

    meta =
      (old.meta or {})
      // {
        description = "Kalshi tennis market research and paper trading (never places real orders)";
        mainProgram = "kalshi-trader";
      };
  })
