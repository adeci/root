_: {
  services.printing = {
    enable = true;
    browsedConf = ''
      CreateIPPPrinterQueues Driverless
    '';
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true; # resolve .local addresses
    openFirewall = true;
  };
}
