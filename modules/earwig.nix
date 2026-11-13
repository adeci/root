{
  # Dictation: hold the hotkey to talk, tap it to keep recording; the default model is pinned in the store, so nothing downloads at runtime.
  nixos =
    { inputs, ... }:
    {
      imports = [ inputs.earwig.nixosModules.default ];

      # Super+Space, which earwig reads itself (the udev uaccess rule of `services.earwig.keyboardAccess`), so no compositor binds.
      services.earwig.enable = true;
    };

  darwin =
    { inputs, ... }:
    {
      imports = [ inputs.earwig.darwinModules.default ];

      # Option+Space; earwig asks for Microphone and Accessibility access on first start and after each update.
      services.earwig.enable = true;
    };
}
