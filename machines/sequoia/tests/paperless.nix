{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;
  inherit (self.inventory.lan) hosts vlans;
  prefixLength = lib.toInt (lib.last (lib.splitString "/" vlans.trusted.cidr));

  llmPort = 8199;

  # Runs a clan vars generator from the modules.
  generate =
    name: generator:
    pkgs.runCommand "vars-${name}" { nativeBuildInputs = generator.runtimeInputs or [ ]; } ''
      set -euo pipefail
      mkdir -p "$out"
      ${generator.script}
    '';

  # Stands in for clan: accepts the modules' clan settings and points each vars file at its generator's output.
  clan =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
      freeform = types.attrsOf types.anything;
    in
    {
      options.clan.core = {
        state = mkOption { type = freeform; };
        postgresql = mkOption { type = freeform; };
        vars.generators = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, config, ... }:
              let
                generated = generate name config;
              in
              {
                freeformType = freeform;
                options.files = mkOption {
                  type = types.attrsOf (
                    types.submodule (
                      { name, ... }:
                      {
                        freeformType = freeform;
                        options.path = mkOption {
                          type = types.str;
                          default = "${generated}/${name}";
                        };
                      }
                    )
                  );
                };
              }
            )
          );
        };
      };
    };

  # A utility bill dated in US order, scanned sideways and slightly skewed.
  scan =
    let
      lines = [
        "ACME POWER COMPANY"
        "Electricity statement"
        "Statement date: 03/04/2025"
        "Account number: 4417-2290-31"
        "Service address: 12 Example Street, Springfield"
        ""
        "Previous balance                                $84.20"
        "Payment received, thank you                     $84.20"
        "Balance forward                                  $0.00"
        ""
        "Delivery charges"
        "  Basic service charge                          $18.00"
        "  Distribution, 412 kWh at $0.0721              $29.71"
        "  System benefit charge                          $3.12"
        "Supply charges"
        "  Energy supply, 412 kWh at $0.1088             $44.83"
        "  Merchant function charge                       $1.97"
        ""
        "Current charges                                 $97.63"
        "Amount due                                      $97.63"
        "Please pay by 03/25/2025"
        ""
        "Your usage this period was 412 kWh over 29 days, an average"
        "of 14.2 kWh per day. Last year you used 455 kWh in the same"
        "period. Thank you for being a valued customer of Acme Power."
      ];
      drawLines = lib.concatImapStringsSep " " (
        i: line: "-annotate +250+${toString (250 + i * 110)} ${lib.escapeShellArg line}"
      ) lines;
    in
    # A Letter page at 300 dpi, rotated 90° plus 1.5° of skew.
    pkgs.runCommand "scan.pdf" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 2550x3300 xc:white -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf \
        -pointsize 50 -fill black ${drawLines} \
        -background white -rotate 91.5 +repage -units PixelsPerInch -density 300 $out
    '';

  # Logs each request, holds its answer until /run/mock-llm/release exists, then files the bill.
  mockLlm = pkgs.writers.writePython3 "mock-llm" { } (builtins.readFile ./mock-llm.py);
in
pkgs.testers.runNixOSTest {
  name = "sequoia-paperless";
  node.specialArgs = { inherit self inputs; };

  nodes.sequoia =
    { lib, pkgs, ... }:
    {
      imports = [
        clan
        self.modules.nixos.primary-user
        ../modules/paperless.nix
        ../modules/paperless-xerox-ingest.nix
      ];

      system.primaryUser = "alex";

      virtualisation = {
        memorySize = 4096;
        cores = 2;
      };
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = hosts.sequoia.ip;
          inherit prefixLength;
        }
      ];
      # The test talks to Paperless directly; nginx would need the real wildcard certificate.
      services.nginx.enable = lib.mkForce false;
      environment.systemPackages = [
        pkgs.jq
        pkgs.poppler-utils
      ];

      systemd.services.mock-llm = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${mockLlm} ${toString llmPort}";
          RuntimeDirectory = "mock-llm";
        };
      };

      # AI filing switched on; the test switches into this and back out.
      specialisation.ai.configuration.paperlessAi = {
        enable = true;
        endpoint = "http://127.0.0.1:${toString llmPort}/v1";
        model = "test-model";
      };
    };

  nodes.printer =
    { lib, nodes, ... }:
    {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = hosts.printer.ip;
          inherit prefixLength;
        }
        # A second address, standing in for any other LAN client.
        {
          address = vlans.trusted.dhcpPool.start;
          inherit prefixLength;
        }
      ];
      environment.etc.ftp-password.source =
        nodes.sequoia.clan.core.vars.generators.paperless-xerox-ingest.files.ftp-password.path;
    };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.sequoia.services) paperless;
    in
    ''
      password_file = "${paperless.passwordFile}"
      port = ${toString paperless.port}
      consume = "${paperless.consumptionDir}"
      data_dir = "${paperless.dataDir}"
      sequoia_ip = "${hosts.sequoia.ip}"
      other_client_ip = "${vlans.trusted.dhcpPool.start}"
      scan = "${scan}"
    ''
    + builtins.readFile ./paperless.py;
}
