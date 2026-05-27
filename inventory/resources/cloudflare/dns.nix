# DNS records managed via Terraform.
# The "target" field references a terraform resource symbolically —
# the terranix logic layer resolves it to the actual terraform expression.
{
  # Forgejo Git SSH on conduit (Hetzner)
  git_ssh = {
    zone = "decio.us";
    name = "git-ssh";
    type = "A";
    proxied = false;
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };

  # Minecraft servers on conduit (Hetzner)
  mc_rlc = {
    zone = "adeci.net";
    name = "rlc";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_rats = {
    zone = "adeci.net";
    name = "rats";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_dj2 = {
    zone = "adeci.net";
    name = "dj2";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_bruh = {
    zone = "adeci.net";
    name = "bruh";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_hunter = {
    zone = "adeci.net";
    name = "hunter";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_jav = {
    zone = "adeci.net";
    name = "jav";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };
  mc_usf = {
    zone = "adeci.net";
    name = "usf";
    type = "A";
    target = {
      resource = "hcloud_server";
      name = "conduit";
      field = "ipv4_address";
    };
  };

  # Minecraft SRV records
  srv_rlc = {
    zone = "adeci.net";
    name = "_minecraft._tcp.rlc";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25565;
      target = "rlc.adeci.net";
    };
  };
  srv_rats = {
    zone = "adeci.net";
    name = "_minecraft._tcp.rats";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25566;
      target = "rats.adeci.net";
    };
  };
  srv_hunter = {
    zone = "adeci.net";
    name = "_minecraft._tcp.hunter";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25567;
      target = "hunter.adeci.net";
    };
  };
  srv_jav = {
    zone = "adeci.net";
    name = "_minecraft._tcp.jav";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25570;
      target = "jav.adeci.net";
    };
  };
  srv_dj2 = {
    zone = "adeci.net";
    name = "_minecraft._tcp.dj2";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25568;
      target = "dj2.adeci.net";
    };
  };
  srv_usf = {
    zone = "adeci.net";
    name = "_minecraft._tcp.usf";
    type = "SRV";
    data = {
      priority = 0;
      weight = 0;
      port = 25569;
      target = "usf.adeci.net";
    };
  };
}
