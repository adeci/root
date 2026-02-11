{ pkgs, wrappers, ... }:
{
  starship =
    (wrappers.wrapperModules.starship.apply {
      inherit pkgs;

      settings = {
        format = "$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration\n$character";

        username = {
          show_always = true;
          format = "[$user]($style)@";
          style_user = "bold blue";
          style_root = "bold red";
        };

        hostname = {
          ssh_only = false;
          format = "[$hostname]($style) ";
          style = "bold green";
        };

        directory = {
          truncation_length = 3;
          format = "[$path]($style)[$read_only]($read_only_style) ";
          style = "bold cyan";
        };

        git_branch = {
          symbol = "";
          format = "[$symbol $branch]($style) ";
          style = "bold purple";
        };

        git_status = {
          format = "[$all_status$ahead_behind]($style)";
          style = "bold red";
        };

        nix_shell = {
          format = " [$symbol]($style) ";
          symbol = "";
          style = "bold blue";
        };

        cmd_duration = {
          min_time = 2000;
          format = " [$duration]($style)";
          style = "bold yellow";
        };

        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };

    }).wrapper;
}
