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

      extraModules = [
        { services.syncthing.user = "alex"; }
      ];

      settings = {
        extraDevices = {
          razr = {
            id = "PXAMRHT-G7OA3GU-VMEBK2F-TPQTS55-4A4KBXO-AWATRBJ-FZ7KH7L-3OU2GQA";
            name = "razr";
          };
        };

        folders = {
          notes = {
            path = "/home/alex/notes";
          };
        };

      };
    };
  };

}
