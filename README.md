# nix-inputs

Personal Nix packages, an overlay, and NixOS modules, exposed as one flake input.

| Attribute | What it is |
| --- | --- |
| `overlays.default` | adds `pkgs.gesturelight`, `pkgs.minimal-grub-theme`, `pkgs.suwayomi-server`, `pkgs.startpage` |
| `nixosModules.default` | overlay + `gesturelight` + `boot.loader.grub.minimalTheme` options |
| `nixosModules.{gesturelight,minimal-grub-theme,overlay}` | the pieces on their own |
| `lib.canvas-local-archive` | `fetchExtension`, `externalExtensions`, `extension` (Canvas Local Archive CRX resolver) |
| `packages.<system>.*` | the four packages, for `nix build .#<name>` |
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

## Startpage extension

`packages.x86_64-linux.startpage` builds the unpacked Terminal Start Page
extension. Its source is pinned from `twempi/startpage` through the
`startpage-src` input, so consumers do not need a local startpage checkout.
The default build uses Rose Pine colors,
Iosevka, and Edward's existing settings server. Override those values to follow
the consuming Home Manager configuration:

```nix
startpage = inputs.twempi.packages.${pkgs.stdenv.hostPlatform.system}.startpage.override {
  colors = config.lib.stylix.colors;
  fontFamily = config.stylix.fonts.monospace.name;
  sansFontFamily = config.stylix.fonts.sansSerif.name;
  startpageOrigin = "https://t480s.tailae03d0.ts.net";
};
```

Add `${startpage}` to Helium's existing comma-separated `--load-extension`
flag. The extension keeps its manifest key, new-tab override, and local
settings cache. It still reads and writes settings through `startpageOrigin`;
packaging does not deploy the settings API or replace the hosted site.

The same pinned source is available as `inputs.twempi.inputs.startpage-src`
for a host's site renderer, settings API, and default settings.

```sh
nix build .#startpage
```

After publishing these changes, update only the `twempi` input in the consuming
flake with `nix flake update twempi`. Until then, validate without staging or
publishing using a path flake:

```sh
nix build path:.#startpage --no-link
```

## Updating

```sh
nix flake update gesturelight-src        # new gesturelight commit
nix flake update minimal-grub-theme-src  # new grub theme commit
nix flake update canvas-scraper-src      # new Canvas extension package
nix flake update startpage-src           # new startpage source commit
nix run .#update-suwayomi                # new Suwayomi release
```

## Adding a package

1. Add `pkgs/<name>.nix` (a `callPackage` file).
2. Add one line to `overlays.default` and to `packages` in `flake.nix`.
3. If it needs a source pin, add a `flake = false` input.

Run `git add -A` before building; flakes ignore untracked files.
