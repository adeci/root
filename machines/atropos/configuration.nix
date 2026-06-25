{
  inputs,
  self,
  ...
}:
{
  imports = [
    inputs.drv-thru.nixosModules.default
    self.users.alex.nixosModule
    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ./modules/hermes-gateway.nix
  ];

  time.timeZone = "America/New_York";

  services.drv-thru.client = {
    enable = true;
    ticketHelper = {
      enable = true;
      group = "drv-thru";
      trustedBuilderPublicKeys = [
        "drv-thru:sWwwRWpZKjcELSsXXpQFUarBIaM5xPj44WQWYoH75GY="
      ];
    };
  };

}
