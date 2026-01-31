{
  lib,
  stdenv,
  appimageTools,
  fetchurl,
  makeWrapper,
  libva,
}:

let
  pname = "helium";
  version = "0.8.4.1";

  src = fetchurl {
    url =
      let
        arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x86_64";
      in
      "https://github.com/imputnet/helium-linux/releases/download/${version}/${pname}-${version}-${arch}.AppImage";
    hash =
      {
        x86_64-linux = "sha256-y4KzR+pkBUuyVU+ALrzdY0n2rnTB7lTN2ZmVSzag5vE=";
        aarch64-linux = "sha256-fTPLZmHAqJqDDxeGgfSji/AY8nCt+dVeCUQIqB80f7M=";
      }
      .${stdenv.hostPlatform.system}
        or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  name = pname;

  nativeBuildInputs = [ makeWrapper ];
  extraPkgs = pkgs: [ pkgs.libva ];

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/${pname}.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}'
    cp -r ${appimageContents}/usr/share/icons $out/share

    wrapProgram $out/bin/${pname} \
      --add-flags "--enable-features=VaapiVideoDecodeLinuxGL,VaapiVideoEncoder"
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
