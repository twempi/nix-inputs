# nix-inputs

Personal Nix packages, an overlay, and NixOS modules, exposed as one flake input.

| Attribute | What it is |
| --- | --- |
| `overlays.default` | adds `pkgs.gesturelight`, `pkgs.minimal-grub-theme`, `pkgs.suwayomi-server` |
| `nixosModules.default` | overlay + `gesturelight` + `boot.loader.grub.minimalTheme` options |
| `nixosModules.{gesturelight,minimal-grub-theme,overlay}` | the pieces on their own |
| `lib.canvas-local-archive` | `fetchExtension`, `externalExtensions`, `extension` (Canvas Local Archive CRX resolver) |
| `packages.<system>.*` | the three packages, for `nix build .#<name>` |
| `apps.<system>.update-suwayomi` | bumps `pkgs/suwayomi-server.nix` to the latest release |

## Use

```nix
# flake.nix
inputs.twempi = {
  url = "github:twempi/nix-inputs";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# NixOS host
{ inputs, ... }: {
  imports = [ inputs.twempi.nixosModules.default ];

  gesturelight = { enable = true; url = "192.168.1.50"; };

  boot.loader.grub.minimalTheme = { enable = true; fontSize = 28; };

  # nixpkgs' own module; the overlay makes it use this repo's version
  services.suwayomi-server.enable = true;
}
```

```nix
# Home Manager / standalone pkgs: add the overlay where pkgs is built
pkgs = import nixpkgs {
  inherit system;
  overlays = [ inputs.twempi.overlays.default ];
};
```

```nix
# Helium extension list: replace the old canvas-local-archive input
fetchExtension = inputs.twempi.lib.canvas-local-archive.fetchExtension { inherit pkgs; };
extensions = [ inputs.twempi.lib.canvas-local-archive.extension ];
```

## Updating

```sh
nix flake update gesturelight-src        # new gesturelight commit
nix flake update minimal-grub-theme-src  # new grub theme commit
nix flake update canvas-scraper-src      # new Canvas extension package
nix run .#update-suwayomi                # new Suwayomi release
```

## Adding a package

1. Add `pkgs/<name>.nix` (a `callPackage` file).
2. Add one line to `overlays.default` and to `packages` in `flake.nix`.
3. If it needs a source pin, add a `flake = false` input.

Run `git add -A` before building; flakes ignore untracked files.
