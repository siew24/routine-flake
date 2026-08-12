{
  lib,
  appimageTools,
  fetchurl,
  variant,
}:
let
  pname = "routine";
  inherit (variant) version url;

  src = fetchurl {
    inherit url;
    hash = variant.sha256;
  };

  appimageContents = appimageTools.extract {
    inherit pname version src;

    # Upstream's AppRun is an installer, not a launcher. On every run it copies
    # the AppImage into ~/.local/bin, writes a desktop entry there, and if a
    # desktop entry already exists it copies itself over whatever path that
    # entry's Exec= points at -- i.e. it self-updates in place. None of that can
    # work from an immutable store path, and updating is the flake's job here,
    # so replace it with a plain exec of the real binary.
    postExtract = ''
      cat > $out/AppRun <<'EOF'
      #!/bin/sh
      # Chromium's ICU works out the current zone by matching /etc/localtime
      # against a known zoneinfo prefix. On NixOS that symlink resolves into
      # /nix/store/...-tzdata-.../share/zoneinfo/..., which ICU does not
      # recognise, so Intl.DateTimeFormat().resolvedOptions().timeZone returns
      # undefined. Routine feeds that straight into a string encoder while its
      # controller bundle is still loading, which throws and leaves the window
      # blank white. Derive the zone name and hand it to ICU explicitly.
      if [ -z "$TZ" ]; then
        _tz=$(readlink -f /etc/localtime 2>/dev/null | sed -n 's#.*/zoneinfo/##p')
        [ -n "$_tz" ] && export TZ="$_tz"
      fi
      exec "$(dirname "$0")/routine" "$@"
      EOF
      chmod +x $out/AppRun
    '';
  };
in
appimageTools.wrapAppImage {
  inherit pname version;

  src = appimageContents;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/${pname}.desktop $out/share/applications/${pname}.desktop

    # electron-builder files the PNG under a bogus "0x0" size directory, which
    # no icon theme will resolve. Ship the bundled SVG as scalable, and drop a
    # copy in pixmaps for launchers that ignore the hicolor index entirely.
    install -m 444 -D ${appimageContents}/resources/share/icon.svg \
      $out/share/icons/hicolor/scalable/apps/${pname}.svg
    install -m 444 -D ${appimageContents}/${pname}.png $out/share/pixmaps/${pname}.png

    # Exec=AppRun --no-sandbox %U -> our FHS wrapper. --no-sandbox is kept
    # because chrome-sandbox is not setuid inside the wrapper.
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  '';

  meta = {
    description = "Calendar, tasks and notes in a single app";
    homepage = "https://routine.co";
    downloadPage = "https://routine.co/download";
    # Proprietary: free tier plus paid plans, no source published.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}
