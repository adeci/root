# shellcheck shell=bash
# Blizzard's launcher through Proton, outside Steam. The first start installs it; games install from inside it.
export WINEPREFIX=$HOME/Games/battlenet GAMEID=umu-battlenet
# Lutris's installer turns the launcher's location lookup off the same way.
export WINEDLLOVERRIDES=locationapi=d
launcher="$WINEPREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"

mkdir -p "$WINEPREFIX"
exec > "$WINEPREFIX/battlenet.log" 2>&1

if [ -e "$launcher" ]; then
  umu-run "$launcher" &
else
  curl --fail --silent --show-error --location --retry 3 --output "$WINEPREFIX/Battle.net-Setup.exe" \
    'https://www.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP'
  # With these two options the installer asks nothing. It starts the launcher when it is done.
  umu-run "$WINEPREFIX/Battle.net-Setup.exe" --lang=enUS '--installpath=C:\Program Files (x86)\Battle.net' &
fi
umu=$!

# The stream ends when this script does. umu-run is no guide: it returns once every Windows program has
# exited, and some of Blizzard's stay behind after the launcher and the games have closed.
unit=/sys/fs/cgroup$(cut -d: -f3- /proc/self/cgroup)

# Pids of the programs the stream is for, among this unit's processes: the launcher, its installer, the games.
# Not Wine's and Proton's own, not Blizzard's updater in ProgramData, and not what the launcher keeps below
# its own directory, such as the overlay.
programs() {
  local pid name
  while read -r pid; do
    IFS= read -r -d '' name 2> /dev/null < "/proc/$pid/cmdline" || continue
    case ${name,,} in
      [a-z]:[\\/]windows[\\/]* | *[\\/]nix[\\/]store[\\/]*) ;;
      [a-z]:[\\/]programdata[\\/]* | [a-z]:[\\/]"program files (x86)"[\\/]battle.net[\\/]*[\\/]*) ;;
      *.exe) echo "$pid" ;;
    esac
  done < "$unit/cgroup.procs"
}

# Linux tells when a process exits, not when one starts. So wait for the programs that run, and look again
# when none does.
started=false
while kill -0 "$umu" 2> /dev/null; do
  mapfile -t pids < <(programs)
  if [ ${#pids[@]} -gt 0 ]; then
    started=true
    waitpid --exited "${pids[@]}"
  elif $started; then
    # The last program has gone. The launcher may be handing over to a game or restarting itself to update:
    # give a successor thirty seconds.
    waitpid --exited --timeout 30 "$umu" || [ -n "$(programs)" ] || break
  else
    waitpid --exited --timeout 1 "$umu" || true
  fi
done

if ! $started; then
  wait "$umu"
fi
