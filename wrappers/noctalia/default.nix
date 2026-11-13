{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.noctalia ];

  config = {
    settings = lib.importTOML ./config.toml;

    # Fails on errors only; unknown keys and wrong types are warnings in the build log.
    buildCommand.validateSettings = {
      after = [ "constructFiles" ];
      data = "${lib.getExe config.package} config validate ${config.constructFiles.settings.path}";
    };
  };
}
