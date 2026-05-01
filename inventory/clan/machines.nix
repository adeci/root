{

  aegis = {
    name = "aegis";
    tags = [
      "adeci-net"
      "wayfinders"
      "keybearers"
    ];
    deploy.targetHost = "root@aegis.cymric-daggertooth.ts.net";
  };

  janus = {
    name = "janus";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@janus.cymric-daggertooth.ts.net";
  };

  conduit = {
    name = "conduit";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@conduit.cymric-daggertooth.ts.net";
  };

  compute-lab = {
    name = "compute-lab";
    tags = [
      "adeci-net-ephemeral"
    ];
    deploy.targetHost = "root@compute-lab.lan";
  };

  chrysalis = {
    name = "chrysalis";
    tags = [
      "adeci-net-ephemeral"
      "wayfinders"
    ];
  };

  kasha = {
    name = "kasha";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@kasha.cymric-daggertooth.ts.net";
  };

  leviathan = {
    name = "leviathan";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@leviathan.cymric-daggertooth.ts.net";
  };

  malum = {
    name = "malum";
    tags = [ ];
    machineClass = "darwin";
    deploy.targetHost = "root@localhost"; # local only for work
  };

  modus = {
    name = "modus";
    tags = [
      "adeci-net"
      "wayfinders"
    ];
    deploy.targetHost = "root@modus.cymric-daggertooth.ts.net";
  };

  praxis = {
    name = "praxis";
    tags = [
      "adeci-net"
      "wayfinders"
      "keybearers"
    ];
    deploy.targetHost = "root@praxis.cymric-daggertooth.ts.net";
  };

  proteus = {
    name = "proteus";
    tags = [
      "adeci-net"
      "wayfinders"
    ];
    deploy.targetHost = "root@proteus.cymric-daggertooth.ts.net";
  };

  sequoia = {
    name = "sequoia";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@sequoia.cymric-daggertooth.ts.net";
  };

}
