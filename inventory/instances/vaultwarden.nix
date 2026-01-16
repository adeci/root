{
  "sequoia-vault" = {
    module = {
      name = "@onix/vaultwarden";
      input = "self";
    };
    roles.server = {
      machines.sequoia = {
        settings = {
          DOMAIN = "https://vault.decio.us";
        };
      };
    };
  };

  "praxis-vault" = {
    module = {
      name = "@onix/vaultwarden";
      input = "self";
    };
    roles.server = {
      machines.praxis = {
        settings = {
          DOMAIN = "https://vault2.decio.us";
        };
      };
    };
  };
}
