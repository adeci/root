{ inputs, applyPatches }:
{
  # For Vencord >= 1.15.16 (no Forms) and Discord's rspack bundle; drop once vencord-pelican has both.
  "pelican.desktop" = applyPatches {
    name = "pelican-source";
    src = inputs.pelican.pluginSource;
    patches = [ ./pelican-vencord-1.15.16.patch ];
  };
}
