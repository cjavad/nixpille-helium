# nixpille-helium

Nix flake packaging the [Helium](https://helium.computer/) browser with a Home Manager module.

## Quick start

Run directly:

```sh
nix run github:cjavad/nixpille-helium
```

Or add as a flake input:

```nix
# flake.nix
inputs.helium = {
  url = "github:cjavad/nixpille-helium";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then add the Home Manager module:

```nix
# In your HM shared modules
hmModules = [
  inputs.helium.homeModules.default
];
```

## Home Manager module

```nix
programs.helium = {
  enable = true;

  # CLI flags passed to the browser
  commandLineArgs = [
    "--ozone-platform-hint=auto"
    "--enable-features=WaylandWindowDecorations"
    "--enable-wayland-ime=true"
  ];

  # Chrome Web Store extensions (installed via Helium's privacy proxy)
  extensions = [
    { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
    { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
  ];

  # Local CRX extension
  # extensions = [{
  #   id = "aaaaaaaaaabbbbbbbbbbccccccccccdd";
  #   crxPath = "/path/to/extension.crx";
  #   version = "1.0";
  # }];

  # dictionaries = [ pkgs.hunspellDictsChromium.en_US ];
  # nativeMessagingHosts = [ pkgs.browserpass ];
};
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | `bool` | `false` | Enable Helium browser |
| `package` | `package` | flake default | The Helium package to use |
| `finalPackage` | `package` | (read-only) | Package with commandLineArgs applied |
| `commandLineArgs` | `[str]` | `[]` | CLI flags passed to Helium |
| `extensions` | `[ext]` | `[]` | Chrome Web Store or local CRX extensions |
| `dictionaries` | `[package]` | `[]` | Spelling dictionary packages |
| `nativeMessagingHosts` | `[package]` | `[]` | Native messaging host packages |

Extensions use Helium's privacy proxy (`services.helium.imput.net/ext`) by default
instead of contacting Google directly.

## Package details

- Packages the upstream `tar.xz` release (not AppImage) with `autoPatchelfHook`
- VA-API hardware video acceleration enabled by default (`libva` + feature flags)
- Qt6 platform integration via `wrapQtAppsHook`
- Desktop entry and icon installed from upstream assets
- Supports both `x86_64-linux` and `aarch64-linux`
- Config directory: `~/.config/net.imput.helium/`

## Updating

Version and SRI hashes live in `sources.json`, which `package.nix` reads
at evaluation time. To update to the latest release:

```sh
./update.sh
```

The script queries the GitHub API, downloads both architecture tarballs,
**verifies GPG signatures** against the Helium signing key
(`BE677C1989D35EAB2C5F26C9351601AD01D6378E`), computes SRI hashes, and
writes `sources.json`. Requires `gh`, `nix`, `gpg`, `curl`, and `jq`.

A GitHub Actions workflow (`.github/workflows/update.yml`) runs daily,
performs the same GPG-verified update, builds the package, and creates a
tagged release if a new upstream version is found.

## Flake outputs

- `packages.{x86_64,aarch64}-linux.default` — Helium package
- `homeModules.default` — Home Manager module
- `overlays.default` — adds `pkgs.helium`

## Integrity

Upstream releases are signed with GPG key
[`BE67 7C19 89D3 5EAB 2C5F 26C9 3516 01AD 01D6 378E`](https://keys.openpgp.org/search?q=helium%40imput.net)
(`Helium signing key <helium@imput.net>`). Both the update script and CI
workflow verify signatures before committing new hashes.
