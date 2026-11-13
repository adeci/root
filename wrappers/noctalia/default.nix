{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.noctalia ];

  settings = {
    shell = {
      polkit_agent = true;
      setup_wizard_enabled = false;
    };

    # Noctalia's defaults, pinned: nothing else locks the screen before suspend, lid close included.
    lockscreen = {
      enabled = true;
      lock_before_suspend = true;
    };

    # Defining behaviors replaces noctalia's built-in ones, so these repeat their action and timeout.
    idle.behavior = {
      lock = {
        action = "lock";
        timeout = 600;
        enabled = false;
      };
      screen-off = {
        action = "screen_off";
        timeout = 660;
        enabled = false;
      };
    };
  };

  # Fails on errors only; unknown keys and wrong types are warnings in the build log.
  buildCommand.validateSettings = {
    after = [ "constructFiles" ];
    data = "${lib.getExe config.package} config validate ${config.constructFiles.settings.path}";
  };
}
