{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.harmonia.nixosModules.harmonia
  ];

  # Vars generator: nix binary cache signing key pair (auto-generated)
  clan.core.vars.generators.harmonia-signing-key = {
    share = true;
    files = {
      signing-key = { };
      "signing-key.pub".secret = false;
    };
    runtimeInputs = [ pkgs.nix ];
    script = ''
      nix-store --generate-binary-cache-key \
        leviathan-harmonia-1 \
        "$out"/signing-key \
        "$out"/signing-key.pub
    '';
  };

  services.harmonia-dev.cache = {
    enable = true;
    signKeyPaths = [
      config.clan.core.vars.generators.harmonia-signing-key.files.signing-key.path
    ];
  };

  services.harmonia-dev.daemon.enable = true;

  nix.settings.extra-allowed-users = [ "harmonia" ];
}
