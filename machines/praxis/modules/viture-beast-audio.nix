# WirePlumber cannot match ELD metadata, so this machine-specific VITURE PCM match uses the connector path.
_: {
  services.pipewire.wireplumber.extraConfig."51-viture-beast-sink" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "alsa.components" = "HDA:1002aa01,00aa0100,00100900";
            "api.alsa.path" = "hdmi:0,3";
          }
        ];
        actions.update-props = {
          "node.description" = "VITURE Beast Speakers";
        };
      }
    ];
  };
}
