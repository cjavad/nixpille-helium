self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.helium;

  configDir = "${config.xdg.configHome}/net.imput.helium";

  wrappedPackage =
    if cfg.commandLineArgs == [ ] then
      cfg.package
    else
      pkgs.runCommand "helium-wrapped"
        {
          nativeBuildInputs = [ pkgs.makeWrapper ];
          meta.mainProgram = "helium";
        }
        ''
          mkdir -p $out/bin
          makeWrapper ${cfg.package}/bin/helium $out/bin/helium \
            --add-flags ${lib.escapeShellArg (lib.concatStringsSep " " cfg.commandLineArgs)}
          ln -s ${cfg.package}/share $out/share
        '';

  extensionJson =
    ext:
    assert ext.crxPath != null -> ext.version != null;
    {
      name = "${configDir}/External Extensions/${ext.id}.json";
      value.text = builtins.toJSON (
        if ext.crxPath != null then
          {
            external_crx = ext.crxPath;
            external_version = ext.version;
          }
        else
          {
            external_update_url = ext.updateUrl;
          }
      );
    };

  dictionary = pkg: {
    name = "${configDir}/Dictionaries/${pkg.passthru.dictFileName}";
    value.source = pkg;
  };

  nativeMessagingHostsJoined = pkgs.symlinkJoin {
    name = "helium-native-messaging-hosts";
    paths = cfg.nativeMessagingHosts;
  };
in
{
  options.programs.helium = {
    enable = lib.mkEnableOption "Helium browser";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The Helium package to use.";
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Resulting customized Helium package.";
    };

    commandLineArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--ozone-platform-hint=auto"
        "--enable-features=WaylandWindowDecorations"
      ];
      description = "List of command-line arguments to be passed to Helium.";
    };

    extensions = lib.mkOption {
      type =
        with lib.types;
        let
          extensionType = submodule {
            options = {
              id = lib.mkOption {
                type = strMatching "[a-zA-Z]{32}";
                description = "The extension's ID from the Chrome Web Store URL or the unpacked CRX.";
                default = "";
              };

              updateUrl = lib.mkOption {
                type = str;
                default = "https://clients2.google.com/service/update2/crx";
                description = "URL of the extension's update manifest XML file.";
              };

              crxPath = lib.mkOption {
                type = nullOr path;
                default = null;
                description = "Path to the extension's CRX file.";
              };

              version = lib.mkOption {
                type = nullOr str;
                default = null;
                description = "The extension's version, required for local CRX installation.";
              };
            };
          };
        in
        listOf (coercedTo str (v: { id = v; }) extensionType);
      default = [ ];
      example = lib.literalExpression ''
        [
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # ublock origin
          {
            id = "dcpihecpambacapedldabdbpakmachpb";
            updateUrl = "https://raw.githubusercontent.com/AUR/AUR/master/updates.xml";
          }
        ]
      '';
      description = "List of Helium extensions to install.";
    };

    dictionaries = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of Helium dictionaries to install.";
    };

    nativeMessagingHosts = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "List of Helium native messaging hosts to install.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helium.finalPackage = wrappedPackage;

    home.packages = [ cfg.finalPackage ];

    home.file =
      lib.listToAttrs ((map extensionJson cfg.extensions) ++ (map dictionary cfg.dictionaries))
      // {
        "${configDir}/NativeMessagingHosts" = lib.mkIf (cfg.nativeMessagingHosts != [ ]) {
          source = "${nativeMessagingHostsJoined}/etc/chromium/native-messaging-hosts";
          recursive = true;
        };
      };
  };
}
