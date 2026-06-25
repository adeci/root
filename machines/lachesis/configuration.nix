{
  self,
  inputs,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule
    inputs.drv-thru.nixosModules.default
    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
  ];

  time.timeZone = "America/New_York";

  services.drv-thru.client = {
    enable = true;
    ticketHelper.trustedBuilderPublicKeys = [
      "drv-thru:sWwwRWpZKjcELSsXXpQFUarBIaM5xPj44WQWYoH75GY="
    ];
  };
}
