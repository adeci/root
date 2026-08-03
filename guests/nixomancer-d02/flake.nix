{
  description = "Secret-free Nixomancer D02 acceptance guest";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";

      guestModule =
        invalid:
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          rawImage = config.system.build.images.raw;
          rawConfig = rawImage.passthru.config;
          kernelParameters = [
            "init=${rawConfig.system.build.toplevel}/init"
          ]
          ++ rawConfig.boot.kernelParams;
          manifest = builtins.toJSON {
            schema = 1;
            inherit system;
            kernel = "kernel";
            initrd = "initrd";
            root_disk = "root.raw";
            root_disk_format = if invalid then "qcow2" else "raw";
            kernel_parameters = kernelParameters;
          };
        in
        {
          fileSystems."/" = lib.mkDefault {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };

          boot = {
            loader.grub.devices = lib.mkOptionDefault [ "/dev/vda" ];

            initrd.availableKernelModules = [
              "virtio_blk"
              "virtio_net"
              "virtio_pci"
            ];
            kernelParams = [
              "console=ttyS0,115200n8"
              "console=tty0"
            ];
          };

          documentation.enable = false;
          nix.enable = false;

          networking = {
            firewall.allowedTCPPorts = [ 8080 ];
            useDHCP = lib.mkDefault true;
          };

          systemd = {
            sockets.nixomancer-test = {
              description = "Nixomancer D02 TCP acceptance socket";
              wantedBy = [ "sockets.target" ];
              listenStreams = [ "0.0.0.0:8080" ];
              socketConfig.Accept = true;
            };

            services."nixomancer-test@" = {
              description = "Nixomancer D02 TCP acceptance response";
              serviceConfig = {
                ExecStart = pkgs.writeShellScript "nixomancer-d02-response" ''
                  printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 18\r\nConnection: close\r\n\r\nnixomancer-d02-ok\n'
                '';
                StandardInput = "socket";
                StandardOutput = "socket";
              };
            };
          };

          system = {
            build.nixomancerGuest =
              pkgs.runCommandLocal (if invalid then "nixomancer-d02-invalid-guest" else "nixomancer-d02-guest")
                { }
                ''
                  mkdir "$out"
                  printf '%s\n' ${lib.escapeShellArg manifest} > "$out/nixomancer-guest-v1.json"
                  ln -s ${rawConfig.system.build.kernel}/${rawConfig.system.boot.loader.kernelFile} "$out/kernel"
                  ln -s ${rawConfig.system.build.initialRamdisk}/${rawConfig.system.boot.loader.initrdFile} "$out/initrd"
                  ln -s ${rawImage}/${rawImage.passthru.filePath} "$out/root.raw"
                '';
            stateVersion = "26.05";
          };
        };

      mkGuest =
        invalid:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ (guestModule invalid) ];
        };
    in
    {
      nixosConfigurations = {
        nixomancer-d02-guest = mkGuest false;
        nixomancer-d02-invalid = mkGuest true;
      };
    };
}
