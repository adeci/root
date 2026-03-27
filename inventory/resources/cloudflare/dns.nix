# DNS records managed via Terraform.
# The "target" field references a terraform resource symbolically —
# the terranix logic layer resolves it to the actual terraform expression.
{
  # Minecraft servers on conduit (Hetzner)
  mc_rlc = {
    zone = "decio.us";
    name = "rlc";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_rats = {
    zone = "decio.us";
    name = "rats";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_dj2 = {
    zone = "decio.us";
    name = "dj2";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_bruh = {
    zone = "decio.us";
    name = "bruh";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };

  # Minecraft SRV records
  srv_rlc = {
    zone = "decio.us";
    name = "_minecraft._tcp.rlc";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25565;
      target = "rlc.decio.us";
    };
  };
  srv_rats = {
    zone = "decio.us";
    name = "_minecraft._tcp.rats";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25566;
      target = "rats.decio.us";
    };
  };
  srv_dj2 = {
    zone = "decio.us";
    name = "_minecraft._tcp.dj2";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25568;
      target = "dj2.decio.us";
    };
  };
}
