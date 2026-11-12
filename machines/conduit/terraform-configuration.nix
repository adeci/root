{
  config,
  lib,
  self,
  ...
}:
let
  # Hetzner's rescue console and initial setup only, so hardware-backed keys. Picked by comment, so reordering the user's sshKeys doesn't replace the server.
  rescueKeys = [
    "praxis-tpm"
    "modus-tpm"
    "spark"
    "ember"
  ];
  keyNamed = comment: lib.head (lib.filter (lib.hasSuffix " ${comment}") self.users.alex.sshKeys);
in
{
  resource.hcloud_ssh_key = lib.genAttrs rescueKeys (name: {
    inherit name;
    public_key = keyNamed name;
  });

  # nixos-anywhere replaces the Ubuntu image; never let create-time fields force a replacement (wipes disk, new IP).
  resource.hcloud_server.conduit = {
    name = "conduit";
    server_type = "cpx11";
    location = "ash";
    image = "ubuntu-24.04";
    ssh_keys = map (name: config.resource.hcloud_ssh_key.${name} "id") rescueKeys;
    firewall_ids = [ (config.resource.hcloud_firewall.conduit "id") ];

    # Hetzner refuses delete/rebuild via API or console until these are off.
    delete_protection = true;
    rebuild_protection = true;

    labels = {
      managed-by = "terraform";
    };

    lifecycle = {
      prevent_destroy = true;
      ignore_changes = [
        "image"
        "ssh_keys"
      ];
    };
  };

  # For DNS checks and rescue only; reach conduit itself over the tailnet.
  output.conduit_ip = {
    value = config.resource.hcloud_server.conduit "ipv4_address";
    description = "Public IPv4 of conduit";
  };
}
