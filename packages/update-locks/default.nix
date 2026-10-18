# Update root flake inputs, then re-sync the work flake's inherited pins.
# GitHub's anonymous API limit is per IP and easily exhausted, so a token from
# GH_TOKEN, GITHUB_TOKEN or `gh auth token` is passed to these Nix calls only,
# via NIX_CONFIG. Nothing is written to nix.conf or the store.
{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "update-locks";
  runtimeInputs = [ pkgs.git ];
  text = # bash
    ''
      if [[ "''${1:-}" == "-h" || "''${1:-}" == "--help" ]]; then
        echo "Usage: update-locks [INPUT...]"
        echo "Update the named root inputs (default: all), then run"
        echo "'nix flake update root' in work/ so it inherits the same pins."
        exit 0
      fi

      repo=$(git rev-parse --show-toplevel)

      token=''${GH_TOKEN:-''${GITHUB_TOKEN:-}}
      if [[ -z "$token" ]] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
        token=$(gh auth token)
      fi
      if [[ -n "$token" ]]; then
        export NIX_CONFIG="access-tokens = github.com=$token''${NIX_CONFIG:+
      $NIX_CONFIG}"
      else
        echo "update-locks: no GitHub token; using GitHub's anonymous API limit" >&2
      fi

      nix flake update "$@" --flake "$repo"
      nix flake update root --flake "$repo/work"
    '';
}
