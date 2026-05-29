{
  trusted = {
    id = 10;
    prefix = "10.10.0";
    cidr = "10.10.0.0/24";
    gateway = "10.10.0.1";
    dhcpPool = {
      start = "10.10.0.100";
      end = "10.10.0.250";
    };
  };

  iot = {
    id = 20;
    prefix = "10.20.0";
    cidr = "10.20.0.0/24";
    gateway = "10.20.0.1";
    dhcpPool = {
      start = "10.20.0.100";
      end = "10.20.0.250";
    };
  };

  guest = {
    id = 30;
    prefix = "10.30.0";
    cidr = "10.30.0.0/24";
    gateway = "10.30.0.1";
    dhcpPool = {
      start = "10.30.0.100";
      end = "10.30.0.250";
    };
  };

  mgmt = {
    id = 99;
    prefix = "10.99.0";
    cidr = "10.99.0.0/24";
    gateway = "10.99.0.1";
    dhcpPool = {
      start = "10.99.0.100";
      end = "10.99.0.250";
    };
    iface = "br-mgmt";
  };
}
