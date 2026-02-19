{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  qt6,
  glib,
  gdk-pixbuf,
  gtk3,
  nspr,
  nss,
  dbus,
  atk,
  at-spi2-atk,
  cups,
  expat,
  libxcb,
  libxkbcommon,
  at-spi2-core,
  xorg,
  mesa,
  cairo,
  pango,
  systemd,
  alsa-lib,
  libdrm,
  libGL,
  libva,
  pipewire,
  libpulseaudio,
}:

let
  pname = "helium";
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (sources) version;
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url =
      let
        arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64";
      in
      "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${arch}_linux.tar.xz";
    hash =
      sources.hashes.${stdenv.hostPlatform.system}
        or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    glib
    gdk-pixbuf
    gtk3
    nspr
    nss
    dbus
    atk
    at-spi2-atk
    cups
    expat
    libxcb
    libxkbcommon
    at-spi2-core
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    mesa
    cairo
    pango
    systemd
    alsa-lib
    libdrm
    qt6.qtbase
  ];

  # Helium bundles Qt5 shims for backwards compat; we use Qt6
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
  ];

  # Let wrapQtAppsHook handle Qt env, we compose via makeWrapper
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/helium $out/bin $out/share/applications $out/share/pixmaps
    cp -r ./* $out/opt/helium/

    makeWrapper $out/opt/helium/helium $out/bin/helium \
      "''${qtWrapperArgs[@]}" \
      --set CHROME_WRAPPER "$out/bin/helium" \
      --set CHROME_VERSION_EXTRA "nixpille-helium" \
      --prefix LD_LIBRARY_PATH : "$out/opt/helium:${
        lib.makeLibraryPath [
          libGL
          libva
          pipewire
          libpulseaudio
        ]
      }" \
      --add-flags "--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder"

    install -m 444 $out/opt/helium/helium.desktop $out/share/applications/helium.desktop
    install -m 444 $out/opt/helium/product_logo_256.png $out/share/pixmaps/helium.png

    runHook postInstall
  '';

  meta = {
    description = "A private, fast, and honest web browser";
    homepage = "https://github.com/imputnet/helium-linux";
    license = lib.licenses.gpl3Only;
    mainProgram = pname;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
