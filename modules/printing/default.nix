{
  nixos =
    { pkgs, self, ... }:
    let
      # From `driverless`, minus a duplicate media type that cupstestppd rejects.
      xeroxPpd = pkgs.runCommand "xerox-workcentre-6605dn-ppd" { } ''
        install -Dm444 ${./xerox-workcentre-6605dn.ppd} $out/share/cups/model/xerox-workcentre-6605dn.ppd
      '';
    in
    {
      services.printing = {
        enable = true;
        drivers = [ xeroxPpd ];
        # Would add a duplicate Xerox queue; CUPS finds printers itself.
        browsed.enable = false;
      };
      hardware.printers = {
        ensurePrinters = [
          {
            name = "Xerox_WorkCentre_6605DN";
            description = "Xerox WorkCentre 6605DN";
            location = "Home";
            # No trailing slash: the printer rejects ipp/print/, though it advertises it.
            deviceUri = "ipp://${self.inventory.lan.hosts.printer.ip}/ipp/print";
            # "everywhere" queries the printer at CUPS start, which fails away from home.
            model = "xerox-workcentre-6605dn.ppd";
          }
        ];
        ensureDefaultPrinter = "Xerox_WorkCentre_6605DN";
      };
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
    };
}
