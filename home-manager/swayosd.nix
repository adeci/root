{ pkgs, lib, ... }:
{
  services.swayosd = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    stylePath = pkgs.writeText "swayosd-style.css" ''
      window {
        background: #000000;
        border-radius: 8px;
        border: 2px solid #7aa2f7;
      }
      progressbar progress {
        background: #7aa2f7;
      }
      label,
      image {
        color: #c0caf5;
      }
    '';
  };
}
