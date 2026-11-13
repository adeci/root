let
  shared =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.kagi-search;
      kagi-search =
        pkgs.runCommand "kagi-search"
          {
            nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
            meta.mainProgram = "kagi-search";
          }
          ''
            mkdir -p $out
            cp -r ${package}/share $out/share
            makeWrapper ${lib.getExe package} $out/bin/kagi-search \
              --set-default KAGI_SESSION_FILE ${config.clan.core.vars.generators.kagi-search.files.session-link.path}
          '';
    in
    {
      clan.core.vars.generators.kagi-search = {
        share = true;
        files.session-link = {
          secret = true;
          owner = config.system.primaryUser;
          mode = "0400";
        };
        prompts.session-link = {
          description = "Kagi session link or token for kagi-search on AI-tools machines";
          type = "hidden";
          persist = true;
        };
      };

      environment.systemPackages = [ kagi-search ];

      home.links.".agents/skills/kagi-search" = "${kagi-search}/share/skills/kagi-search";
    };
in
{
  nixos =
    { config, self, ... }:
    {
      imports = [
        self.modules.nixos.home-links
        self.modules.nixos.primary-user
        shared
      ];

      clan.core.vars.generators.kagi-search.files.session-link.group =
        config.users.users.${config.system.primaryUser}.group;
    };

  darwin =
    { self, ... }:
    {
      imports = [
        self.modules.darwin.home-links
        self.modules.darwin.primary-user
        shared
      ];

      # The group macOS gives every account.
      clan.core.vars.generators.kagi-search.files.session-link.group = "staff";
    };
}
