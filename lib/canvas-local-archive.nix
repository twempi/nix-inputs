# Re-exports the resolver helpers that live in the canvas-scraper repo.
# `src` is the canvas-scraper-src flake input (a plain source tree).
src: {
  # fetchExtension { inherit pkgs; } -> { id, hash }: derivation
  fetchExtension = import "${src}/nix/fetch-extension.nix";

  # externalExtensions { inherit lib pkgs; } -> { configFiles = ...; }
  externalExtensions = import "${src}/nix/external-extensions.nix";

  # The { id; hash; } entry for the signed Canvas Local Archive CRX.
  extension = import "${src}/packages/entry.nix";
}
