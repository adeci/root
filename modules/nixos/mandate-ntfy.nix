# The token mandate's console publishes to sequoia's ntfy with. Shared, so
# sequoia's ntfy and lachesis's console hold the same value.
{ pkgs, ... }:
{
  clan.core.vars.generators.mandate-ntfy = {
    share = true;
    files.token.secret = true;
    runtimeInputs = [ pkgs.ntfy-sh ];
    script = ''
      ntfy token generate | tr -d '\n' > "$out"/token
    '';
  };
}
