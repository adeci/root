{
  config,
  inputs,
  pkgs,
  ...
}:
let
  micsSkills = inputs.mics-skills;
  micsSkillsPkgs = micsSkills.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.opencrow.nixosModules.default
    ./kagi.nix
  ];

  config = {
    # Match UIDs across host and container so bind mounts work cleanly.
    containers.opencrow.config.users.users.opencrow.uid = 2000;
    containers.opencrow.config.users.groups.opencrow.gid = 2000;
    users.groups.opencrow.gid = 2000;

    # --- Matrix credentials ---
    # The watari user is created declaratively by the matrix-synapse module.
    # One-time setup after first deploy:
    #
    # 1. Read watari's password from vars:
    #      clan vars get sequoia matrix-password-watari matrix-password-watari
    #
    # 2. Generate an access token:
    #      curl -s -X POST https://matrix.decio.us/_matrix/client/v3/login \
    #        -d '{"type":"m.login.password","user":"watari","password":"<password>"}' \
    #        | jq -r '.access_token'
    #
    # 3. Store it:
    #      clan vars set sequoia opencrow-matrix access-token
    #
    # The token persists across deploys — watari is re-checked but not
    # re-registered, so existing sessions stay valid.

    clan.core.vars.generators.opencrow-matrix = {
      files.access-token.secret = true;
      prompts.access-token = {
        description = "Matrix access token for @watari:decio.us";
        type = "hidden";
        persist = true;
      };
      script = ''
        printf 'OPENCROW_MATRIX_ACCESS_TOKEN=%s\n' "$(cat "$prompts/access-token")" > "$out/access-token"
      '';
    };

    services.opencrow = {
      enable = true;
      piPackage = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi;

      # Load the access token as an environment file.
      environmentFiles = [
        config.clan.core.vars.generators.opencrow-matrix.files.access-token.path
      ];

      skills = {
        kagi-search = "${micsSkills}/skills/kagi-search";
        context7 = "${micsSkills}/skills/context7-cli";
        web = "${
          inputs.opencrow.packages.${pkgs.stdenv.hostPlatform.system}.opencrow
        }/share/opencrow/skills/web";
      };

      environment = {
        OPENCROW_BACKEND = "matrix";
        OPENCROW_MATRIX_HOMESERVER = "http://127.0.0.1:8008";
        OPENCROW_MATRIX_USER_ID = "@watari:decio.us";
        OPENCROW_ALLOWED_USERS = "@alex:decio.us";
        OPENCROW_SOUL_FILE = "${./soul.md}";
        OPENCROW_LOG_LEVEL = "debug";
        OPENCROW_PI_PROVIDER = "anthropic";
        OPENCROW_PI_MODEL = "claude-sonnet-4-6";
        OPENCROW_SHOW_TOOL_CALLS = "true";
      };

      extraPackages = [
        micsSkillsPkgs.kagi-search
        micsSkillsPkgs.context7-cli
      ]
      ++ (with pkgs; [
        curl
        file
        git
        jq
        less
        tree
        w3m
        which
      ]);
    };
  };
}
