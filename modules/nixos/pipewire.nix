# Audio via PipeWire with ALSA and PulseAudio compatibility.
_: {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;

    # Set Shure MV7+ capture volume to 100% when connected.
    wireplumber.extraConfig."50-shure-mv7+" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_input.*Shure.*MV7.*"; }
          ];
          actions.update-props = {
            "node.volume" = 1.0;
          };
        }
      ];
    };
  };
}
