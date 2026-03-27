# Audio via PipeWire with ALSA and PulseAudio compatibility.
_: {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
