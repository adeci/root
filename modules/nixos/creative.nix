{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    blender
    freecad
    openscad
    audacity
    # WebKit's gamepad support calls libmanette → hidapi. hid_get_device_info()
    # returns an invalid non-NULL pointer (0x31) for some hidraw devices,
    # causing a segfault when libmanette dereferences it. Stub hid_get_device_info
    # to validate the return value — this IS an exported hidapi symbol so
    # LD_PRELOAD works.
    (
      let
        hidapi-fix =
          pkgs.runCommand "hidapi-fix"
            {
              nativeBuildInputs = [ pkgs.gcc ];
            }
            ''
                      mkdir -p $out/lib
                      cat > fix.c << 'EOF'
              #include <dlfcn.h>
              #include <stdint.h>

              struct hid_device_info;

              struct hid_device_info *hid_get_device_info(void *dev) {
                  struct hid_device_info *(*real)(void *) = dlsym(RTLD_NEXT, "hid_get_device_info");
                  struct hid_device_info *info = real(dev);
                  /* hidapi sometimes returns a small invalid pointer instead of NULL */
                  if ((uintptr_t)info < 0x1000)
                      return (void *)0;
                  return info;
              }
              EOF
                      gcc -shared -fPIC -o $out/lib/hidapi-fix.so fix.c -ldl
            '';
      in
      pkgs.symlinkJoin {
        name = "prusa-slicer-wrapped";
        paths = [ prusa-slicer ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/prusa-slicer \
            --set LD_PRELOAD ${hidapi-fix}/lib/hidapi-fix.so
        '';
      }
    )
    obs-studio
    gimp
  ];
}
