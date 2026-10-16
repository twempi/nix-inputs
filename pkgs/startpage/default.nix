{
  pkgs,
  colors ? {
    base00 = "191724";
    base01 = "1f1d2e";
    base02 = "26233a";
    base03 = "6e6a86";
    base05 = "e0def4";
    base08 = "eb6f92";
    base0A = "ebbcba";
    base0B = "31748f";
    base0C = "9ccfd8";
    base0D = "c4a7e7";
    base0E = "f6c177";
  },
  fontFamily ? "Iosevka",
  sansFontFamily ? fontFamily,
  startpageOrigin ? "https://t480s.tailae03d0.ts.net",
}: let
  startpageSource = ./src;
  mkStylixStartpage = import ./mkStylixStartpage.nix;
  startpageSite = mkStylixStartpage {
    inherit pkgs colors fontFamily sansFontFamily;
    source = startpageSource;
  };
in
  pkgs.runCommand "helium-startpage-extension" {nativeBuildInputs = [pkgs.jq];} ''
    mkdir -p "$out"

    cp -R ${startpageSite}/. "$out/"
    chmod -R u+w "$out"

    cat > "$out/script/extension-env.js" <<'EOF'
    window.STARTPAGE_SETTINGS_URL = ${builtins.toJSON "${startpageOrigin}/settings.json"};
    window.STARTPAGE_SETTINGS_API_URL = ${builtins.toJSON "${startpageOrigin}/api/settings"};
    window.STARTPAGE_USE_LOCAL_SETTINGS_CACHE = true;
    EOF

    substituteInPlace "$out/index.html" \
      --replace-fail '<script src="script/storage.js"></script>' \
        '<script src="script/extension-env.js"></script>
      <script src="script/storage.js"></script>'

    jq \
      --arg origin ${builtins.toJSON startpageOrigin} \
      --arg host ${builtins.toJSON "${startpageOrigin}/*"} \
      '
        .chrome_url_overrides.newtab = "focus/focus.html"
        | .host_permissions = (((.host_permissions // []) + [$host]) | unique)
        | .content_security_policy.extension_pages |= (
            if contains($origin) then . else sub("connect-src "; "connect-src \($origin) ") end
          )
      ' ${startpageSource}/manifests/chrome.json > "$out/manifest.json"
  ''
