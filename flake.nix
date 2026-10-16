{
  description = "twempi's personal packages, overlay and NixOS modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # gesturelight is a uv project; uv2nix turns its uv.lock into a Nix build.
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };

    # Source-only pins for your own repos (not flakes, so they pull in nothing
    # else). Bump one with: nix flake update gesturelight-src
    gesturelight-src = {
      url = "github:twempi/gesturelight";
      flake = false;
    };
    minimal-grub-theme-src = {
      url = "github:twempi/minimal-grub-theme";
      flake = false;
    };
    canvas-scraper-src = {
      url = "github:twempi/canvas-scraper";
      flake = false;
    };
    startpage-src = {
      url = "github:twempi/startpage";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    pyproject-nix,
    uv2nix,
    pyproject-build-systems,
    gesturelight-src,
    minimal-grub-theme-src,
    canvas-scraper-src,
    startpage-src,
    ...
  }: let
    systems = ["x86_64-linux"];
    forAll = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        overlays = [self.overlays.default];
      };

    # Makes pkgs.gesturelight etc. available to any host that imports a module.
    overlayModule = {nixpkgs.overlays = [self.overlays.default];};
  in {
    overlays.default = final: _prev: {
      gesturelight = final.callPackage ./pkgs/gesturelight.nix {
        src = gesturelight-src;
        inherit pyproject-nix uv2nix pyproject-build-systems;
      };

      minimal-grub-theme = final.callPackage ./pkgs/minimal-grub-theme.nix {
        src = minimal-grub-theme-src;
      };

      # Same attribute name as nixpkgs on purpose: with the overlay applied,
      # nixpkgs' own services.suwayomi-server uses this version automatically.
      suwayomi-server = final.callPackage ./pkgs/suwayomi-server.nix {};

      startpage = final.callPackage ./pkgs/startpage {
        src = startpage-src;
      };
    };

    packages = forAll (system: {
      inherit
        (pkgsFor system)
        gesturelight
        minimal-grub-theme
        suwayomi-server
        startpage
        ;
    });

    nixosModules = {
      overlay = overlayModule;
      gesturelight.imports = [overlayModule ./modules/gesturelight.nix];
      minimal-grub-theme.imports = [overlayModule ./modules/minimal-grub-theme.nix];
      default.imports = [
        overlayModule
        ./modules/gesturelight.nix
        ./modules/minimal-grub-theme.nix
      ];
    };

    # canvas-scraper is a resolver library, not a package:
    #   fetchExtension, externalExtensions, extension
    lib.canvas-local-archive = import ./lib/canvas-local-archive.nix canvas-scraper-src;

    apps = forAll (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      updater = pkgs.writeShellApplication {
        name = "update-suwayomi";
        runtimeInputs = [pkgs.nix-update];
        text = ''
          exec nix-update --flake --use-github-releases --build suwayomi-server "$@"
        '';
      };
    in {
      update-suwayomi = {
        type = "app";
        program = nixpkgs.lib.getExe updater;
        meta.description = "Bump pkgs/suwayomi-server.nix to the latest stable release";
      };
    });

    checks = forAll (system: self.packages.${system});

    formatter = forAll (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
