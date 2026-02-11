{ pkgs, wrappers, ... }:
{
  swayosd =
    (wrappers.wrapperModules.swayosd.apply {
      inherit pkgs;

      style.content = ''
        window {
          background: #000000;
          border-radius: 8px;
          border: 2px solid #7aa2f7;
        }
        progressbar progress {
          background: #7aa2f7;
        }
        label, image {
          color: #c0caf5;
        }
      '';

    }).wrapper;
}
