_:
{
  clan.core.postgresql.enable = true;
  clan.core.postgresql.databases.atuin = {
    create.enable = false;
    restore.stopOnRestore = [ "atuin" ];
  };

  services.atuin = {
    enable = true;
    openRegistration = false;
    host = "0.0.0.0";
  };
}
