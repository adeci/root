{
  sshd = {
    module = {
      name = "sshd";
      input = "clan-core";
    };
    roles.server.tags.adeci-net = { };
    roles.server.settings.certificate.searchDomains = [
      "cymric-daggertooth.ts.net"
    ];
    roles.client.tags.adeci-net = { };
    roles.client.settings.certificate.searchDomains = [
      "cymric-daggertooth.ts.net"
    ];
  };
}
