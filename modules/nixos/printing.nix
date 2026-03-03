_: {
  services.printing = {
    enable = true;
    browsedConf = ''
      CreateIPPPrinterQueues Driverless
    '';
  };
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };
}
