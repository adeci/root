{ inputs, applyPatches }:
{
  # Ported to Vencord 1.15.16 (no Forms in @webpack/common) and Discord's rspack bundle (anonymous upload function); drop once vencord-pelican has both.
  "pelican.desktop" = applyPatches {
    name = "pelican-source";
    src = inputs.pelican.pluginSource;
    patches = [ ./pelican-vencord-1.15.16.patch ];
  };
}
