{ pkgs, ... }:
let
  thaw = pkgs.writeShellApplication {
    name = "thaw";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.diffutils
      pkgs.git
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      usage() {
        cat <<'EOF'
      usage: thaw <app> [--for DURATION] [--repo PATH | --scratch] [--fresh]
             freeze <app>
             thaw status | diff <app> | reload <app> | repo [PATH]

      thaw <app>    point <app> at editable files: the remembered checkout, or a scratch copy
      freeze <app>  back to the system config (so does --for running out, or a reboot)
      status        which apps are frozen or thawed
      diff <app>    changes against the system config, as a patch for the repo
      reload <app>  tell a running <app> to re-read its files (apps that watch them need nothing)
      repo [PATH]   remember (or show) the checkout `thaw` reads from
      EOF
      }
      die() { echo "thaw: $*" >&2; exit 1; }

      manifests=''${THAW_MANIFESTS:-/etc/thaw}
      runtime=''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/thaw
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/thaw
      mkdir -p "$state"

      # name <TAB> system copy <TAB> repo path ("" if not in the repo)
      files() { jq -r '.files | to_entries[] | [.key, .value.pure, (.value.repo // "")] | @tsv' "$1"; }
      point() { ln -sfn "$2" "$1.new" && mv -Tf "$1.new" "$1"; }

      status() {
        found=0
        for m in "$manifests"/*.json; do
          [ -e "$m" ] || continue
          found=1
          app=$(basename "$m" .json)
          while IFS=$'\t' read -r name pure _; do
            target=$(readlink "$runtime/$app/$name" 2>/dev/null || true)
            case "$target" in
              "") mode=- target="(no link yet)" ;;
              "$pure") mode=frozen ;;
              *) mode=thawed ;;
            esac
            printf '%-10s %-12s %-7s %s\n' "$app" "$name" "$mode" "$target"
          done < <(files "$m")
        done
        [ "$found" = 1 ] || echo "no thaw-capable apps on this machine"
        if [ -e "$state/repo" ]; then echo "checkout: $(cat "$state/repo")"; fi
      }

      [ $# -ge 1 ] || { usage; exit 1; }
      case "$1" in
        -h | --help) usage; exit 0 ;;
        status) status; exit 0 ;;
        repo)
          if [ $# -ge 2 ]; then git -C "$2" rev-parse --show-toplevel > "$state/repo"; fi
          cat "$state/repo" 2>/dev/null || echo "no checkout remembered"
          exit 0
          ;;
        freeze | diff | reload)
          [ $# -ge 2 ] || { usage; exit 1; }
          action=$1 app=$2
          shift 2
          ;;
        *)
          action=thaw app=$1
          shift
          ;;
      esac

      manifest="$manifests/$app.json"
      if [ ! -e "$manifest" ]; then
        known=""
        for m in "$manifests"/*.json; do [ -e "$m" ] && known="$known $(basename "$m" .json)"; done
        die "'$app' can't be thawed here (thaw-capable apps:''${known:- none})"
      fi
      dir="$runtime/$app"
      scratch="$state/$app"
      timer="thaw-$app-freeze"
      mkdir -p "$dir"

      reload() {
        cmd=$(jq -r '.reload // empty' "$manifest")
        [ -z "$cmd" ] || THAW_DIR="$dir" bash -c "$cmd" || echo "thaw: $app did not reload" >&2
      }

      case "$action" in
        thaw)
          duration="" repo="" use_scratch=0 fresh=0
          while [ $# -gt 0 ]; do
            case "$1" in
              --for) duration=$2; shift 2 ;;
              --repo) repo=$2; shift 2 ;;
              --scratch) use_scratch=1; shift ;;
              --fresh) fresh=1; shift ;;
              *) usage; exit 1 ;;
            esac
          done
          root=""
          if [ -n "$repo" ]; then
            root=$(git -C "$repo" rev-parse --show-toplevel) || die "$repo is not a checkout"
          elif [ "$use_scratch" = 0 ]; then
            root=$(git rev-parse --show-toplevel 2>/dev/null || cat "$state/repo" 2>/dev/null || true)
          fi
          if [ -n "$root" ]; then
            while IFS=$'\t' read -r name _ rel; do
              [ -n "$rel" ] || continue
              [ -e "$root/$rel" ] || die "$root/$rel does not exist (is $root this repo?)"
            done < <(files "$manifest")
            echo "$root" > "$state/repo"
            while IFS=$'\t' read -r name _ rel; do
              [ -z "$rel" ] || point "$dir/$name" "$root/$rel"
            done < <(files "$manifest")
            where=$root
          else
            mkdir -p "$scratch"
            while IFS=$'\t' read -r name pure _; do
              if [ "$fresh" = 1 ] || [ ! -e "$scratch/$name" ]; then
                cp -rL --no-preserve=mode "$pure" "$scratch/$name" 2>/dev/null || : > "$scratch/$name"
              fi
              point "$dir/$name" "$scratch/$name"
            done < <(files "$manifest")
            where="a scratch copy in $scratch"
          fi
          reload
          systemctl --user stop "$timer.timer" 2>/dev/null || true
          if [ -n "$duration" ]; then
            systemd-run --user --quiet --collect --unit "$timer" --on-active="$duration" \
              "$(readlink -f "$0")" freeze "$app" || die "could not set the $duration timer"
            echo "thaw: $app reads $where for $duration"
          else
            echo "thaw: $app reads $where until 'freeze $app'"
          fi
          ;;
        freeze)
          while IFS=$'\t' read -r name pure _; do
            point "$dir/$name" "$pure"
          done < <(files "$manifest")
          reload
          systemctl --user stop "$timer.timer" 2>/dev/null || true
          echo "thaw: $app is frozen (back on the system config)"
          ;;
        reload) reload ;;
        diff)
          while IFS=$'\t' read -r name pure rel; do
            edited=$(readlink "$dir/$name" 2>/dev/null || true)
            [ -n "$edited" ] && [ "$edited" != "$pure" ] || continue
            label=''${rel:-$app/$name}
            if [ -d "$pure" ]; then
              diff -ru "$pure" "$edited" | sed "s|$pure|a/$label|; s|$edited|b/$label|" || true
            else
              diff -u --label "a/$label" --label "b/$label" "$pure" "$edited" || true
            fi
          done < <(files "$manifest")
          ;;
      esac
    '';
  };
in
pkgs.symlinkJoin {
  name = "thaw";
  paths = [
    thaw
    (pkgs.writeShellScriptBin "freeze" ''exec ${thaw}/bin/thaw freeze "$@"'')
  ];
  meta.mainProgram = "thaw";
}
