{
  syncthing = {
    module = {
      name = "syncthing";
      input = "clan-core";
    };
    roles.peer = {
      machines = {
        praxis = { };
        aegis = { };
        sequoia = { };
      };
      settings = {
        folders = {
          notes = {
            path = "/home/alex/notes";
          };
        };
        # Phone configured via Syncthing Android app — add device ID here
        # after installing Syncthing on the Razr and copying the ID.
        # extraDevices = {
        #   razr = {
        #     id = "XXXX";
        #     name = "Motorola Razr";
        #   };
        # };
      };
    };
  };
}
