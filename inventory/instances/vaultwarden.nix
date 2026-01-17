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

}
