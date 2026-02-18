{

  # bambrew = {
  #   name = "bambrew";
  #   tags = [
  #     "adeci-net"
  #   ];
  #   deploy.targetHost = "root@bambrew";
  # };

  aegis = {
    name = "aegis";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@aegis";
  };

  claudia = {
    name = "claudia";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@claudia";
  };

  kasha = {
    name = "kasha";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@kasha";
  };

  leviathan = {
    name = "leviathan";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@leviathan";
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
    ];
    deploy.targetHost = "root@modus";
  };

  praxis = {
    name = "praxis";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@praxis";
  };

  sequoia = {
    name = "sequoia";
    tags = [
      "adeci-net"
    ];
    deploy.targetHost = "root@sequoia";
  };

}
