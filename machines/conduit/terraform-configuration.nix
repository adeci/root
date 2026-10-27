{ config, ... }:
{
  # SSH key — used only for Hetzner rescue console / initial provisioning.
  # Pinned to avoid server replacement when sshKeys order changes.
  resource.hcloud_ssh_key.alex = {
    name = "alex";
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVB44hBiASLPelTC//teEK3CpzrwswdBccLe9MKbaMp adecigear";
  };

  # Server. Hetzner creates it from Ubuntu; nixos-anywhere then replaces the OS,
  # so create-time fields must never force a replacement (which wipes the disk
  # and changes the public IP).
  resource.hcloud_server.conduit = {
    name = "conduit";
    server_type = "cpx11";
    location = "ash";
    image = "ubuntu-24.04";
    ssh_keys = [ (config.resource.hcloud_ssh_key.alex "id") ];
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

  # Reach conduit over Tailscale (`ssh root@conduit`); this is for DNS checks
  # and rescue only. `nix run .#tf-output -- -raw conduit_ip`.
  output.conduit_ip = {
    value = config.resource.hcloud_server.conduit "ipv4_address";
    description = "Public IPv4 of conduit";
  };
}
