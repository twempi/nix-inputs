{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.boot.loader.grub.minimalTheme;

  # pkgs.minimal-grub-theme comes from the overlay; override rebuilds the font
  # with the chosen size and character range.
  themePackage = pkgs.minimal-grub-theme.override {
    inherit (cfg) fontSize fontRange;
  };
in {
  options.boot.loader.grub.minimalTheme = {
    enable = lib.mkEnableOption "the minimal GRUB theme";

    fontSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 28;
      description = "Point size used when generating the GRUB PF2 font.";
    };

    fontRange = lib.mkOption {
      type = lib.types.str;
      default = "0x20-0x7e,0xa0-0xff,0x2010-0x2026";
      description = "Character range passed to grub-mkfont.";
    };

    timeout = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = 5;
      description = "Default boot loader timeout in seconds. Use null to wait indefinitely.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.grub.theme = themePackage;
    boot.loader.timeout = lib.mkDefault cfg.timeout;
    boot.loader.grub.timeoutStyle = lib.mkDefault "menu";
  };
}
