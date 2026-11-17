# Sized for 256-core servers.
{ wlib, ... }:
{
  imports = [ wlib.wrapperModules.htop ];

  config = {
    settings = {
      screen_tabs = 1;
      show_program_path = 0;
      show_cpu_frequency = 1;
      column_meters_0 = "AllCPUs8";
      column_meter_modes_0 = 1;
      column_meters_1 = "Hostname Uptime DateTime LoadAverage Systemd Tasks CPU Memory Swap DiskIO NetworkIO";
      column_meter_modes_1 = "2 2 2 2 2 2 1 1 1 2 2";
    };
  };
}
