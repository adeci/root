{
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.btop ];

  settings = {
    vim_keys = true;
    color_theme = "tokyo-night";
    theme_background = false;
    update_ms = 100;

    graph_symbol = "braille";
    graph_symbol_cpu = "braille";
    graph_symbol_gpu = "braille";
    graph_symbol_mem = "braille";
    graph_symbol_net = "braille";
    graph_symbol_proc = "braille";

    cpu_sensor = "k10temp/Tctl";

    show_gpu_info = "Auto";
    gpu_mirror_graph = true;
  };
}
