{ inputs, lib, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      self',
      inputs',
      ...
    }:
    let
      tfConfig = inputs.terranix.lib.terranixConfiguration {
        inherit system;
        modules = [
          ../terranix/base.nix
          ../terranix/b2.nix
          ../terranix/cloudflare.nix
          ../terranix/hcloud.nix
          ../terranix/tailscale.nix
          ../machines/conduit/terraform-configuration.nix
        ];
        extraArgs = {
          inherit (inputs) self;
          inherit self' inputs inputs';
        };
      };

      inherit (self'.packages) clan-cli;

      tofu = import ./tofu-workspace.nix {
        inherit pkgs clan-cli tfConfig;
        workspace = "cloud";
      };
    in
    {
      packages = {
        get-clan-secret = pkgs.writeShellApplication {
          name = "get-clan-secret";
          runtimeInputs = [
            pkgs.jq
            clan-cli
          ];
          text = # bash
            ''
              jq -n --arg secret "$(clan secrets get "$1")" '{"secret":$secret}'
            '';
        };

        provide-tf-passphrase = pkgs.writeShellApplication {
          name = "opentofu-external-key-provider";
          runtimeInputs = [
            pkgs.jq
            clan-cli
          ];
          # Returns the decryption key even without stored metadata: states saved before the metadata existed still need it.
          text = # bash
            ''
              echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'
              cat >/dev/null || true
              PASSPHRASE=$(clan secrets get tf-passphrase)
              jq -n --arg key "$PASSPHRASE" '{"keys":{"encryption_key":($key|@base64),"decryption_key":($key|@base64)},"meta":{"external_data":{}}}'
            '';
        };
      };

      apps =
        lib.genAttrs
          [
            "tf-init"
            "tf-plan"
            "tf-apply"
            "tf-output"
            "tf-state"
            "tf-destroy"
          ]
          (name: {
            program = tofu.command name (lib.removePrefix "tf-" name);
          });
    };
}
