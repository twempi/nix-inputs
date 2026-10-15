{
  pkgs,
  lib,
  src,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}: let
  python = pkgs.python311;

  # These libraries let the OpenCV and MediaPipe wheels use a webcam and open a
  # desktop window.
  runtimeLibraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    libGL
    glib
    libxkbcommon
    libx11
    libxcb
    libxcursor
    libxext
    libICE
    libxi
    libxrandr
    libxrender
    libSM
  ];
  runtimeLibraryPath = lib.makeLibraryPath runtimeLibraries;

  workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = src;};

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {inherit python;}).overrideScope
    (lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {sourcePreference = "wheel";})
    ]);

  inherit (pkgs.callPackages pyproject-nix.build.util {}) mkApplication;

  desktopItem = pkgs.makeDesktopItem {
    name = "gesturelight";
    desktopName = "GestureLight";
    genericName = "Gesture-controlled lamp";
    comment = "Control a local ESP32 lamp with webcam hand gestures";
    exec = "@gesturelight-bin@";
    categories = ["AudioVideo" "Video"];
    terminal = false;
  };
in
  (mkApplication {
    venv = pythonSet.mkVirtualEnv "gesturelight-env" workspace.deps.default;
    package = pythonSet.gesturelight;
  }).overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.makeWrapper];

    postInstall =
      (old.postInstall or "")
      + ''
        install -Dm444 ${desktopItem}/share/applications/gesturelight.desktop \
          "$out/share/applications/gesturelight.desktop"
        substituteInPlace "$out/share/applications/gesturelight.desktop" \
          --replace-fail '@gesturelight-bin@' "$out/bin/gesturelight-hand-tracker"
        wrapProgram "$out/bin/gesturelight-hand-tracker" \
          --set QT_QPA_PLATFORM xcb \
          --prefix LD_LIBRARY_PATH : ${runtimeLibraryPath}
      '';

    # MediaPipe 0.10.21 (the last release with mp.solutions.hands) only has a
    # locked Linux wheel for x86_64.
    meta =
      (old.meta or {})
      // {
        description = "Webcam hand tracking and local ESP32 lamp control";
        mainProgram = "gesturelight-hand-tracker";
        platforms = ["x86_64-linux"];
      };
  })
