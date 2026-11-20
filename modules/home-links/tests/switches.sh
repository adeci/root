# shellcheck shell=bash
set -euo pipefail

# Scratch home, fake store paths.
export HOME=$PWD/home STATE_DIRECTORY=$PWD/state
mkdir -p "$HOME" "$STATE_DIRECTORY" store
one=$PWD/store/one
two=$PWD/store/two
mine=$PWD/store/mine
gone=$PWD/store/gone
touch "$one" "$two" "$mine" "$gone"

fail() {
  echo "home-links test: $*" >&2
  exit 1
}

# Args: "path target" pairs, paths relative to $HOME.
write_table() {
  : >table
  while (($# > 0)); do
    printf '%s\t%s\n' "$HOME/$1" "$2" >>table
    shift 2
  done
}

switch() {
  write_table "$@"
  home-links --check table
  home-links table
}

points_at() {
  [[ -L $HOME/$1 && $(readlink "$HOME/$1") == "$2" ]] || fail "$1 does not point at $2"
}

absent() {
  [[ ! -e $HOME/$1 && ! -L $HOME/$1 ]] || fail "$1 is still there"
}

# Link from before the record existed.
ln -s "$one" "$HOME/.before-record"

switch .changed "$one" .dropped "$one" .dangling "$gone" .repointed "$one" .replaced "$one" \
  .deep/er/link "$one" .shared/link "$one" "Application Support/link" "$one" ".private/kept link" "$one"
points_at .before-record "$one"
points_at .deep/er/link "$one"
points_at "Application Support/link" "$one"
cmp table "$STATE_DIRECTORY/linked" || fail "the record is not the table"

# Manual changes, and a target that's gone.
ln -sfn "$mine" "$HOME/.repointed"
rm "$HOME/.replaced"
echo mine >"$HOME/.replaced"
echo mine >"$HOME/.shared/own"
chmod 700 "$HOME/.private"
echo mine >"$HOME/My Notes"
rm "$gone"

switch .changed "$two" ".private/kept link" "$one"
points_at .changed "$two"
absent .dropped
absent .dangling
points_at .repointed "$mine"
[[ -f $HOME/.replaced && ! -L $HOME/.replaced ]] || fail ".replaced was overwritten"
absent .deep
absent .shared/link
[[ -f $HOME/.shared/own ]] || fail ".shared/own is gone"
absent "Application Support"
points_at .before-record "$one"
points_at ".private/kept link" "$one"
[[ $(stat -c %a "$HOME/.private") == 700 ]] || fail "the folder of a link that stays was made again"

# A real file in a link's place stops the switch before anything changes.
cp "$STATE_DIRECTORY/linked" record-before
write_table .changed "$two" .new "$one" "My Notes" "$one"
if home-links --check table; then fail "the check passed a real file in a link's place"; fi
if home-links table; then fail "the run linked over a real file"; fi
absent .new
points_at ".private/kept link" "$one"
cmp record-before "$STATE_DIRECTORY/linked" || fail "a refused run changed the record"

# Every entry gone.
switch
absent .changed
[[ -f $STATE_DIRECTORY/linked && ! -s $STATE_DIRECTORY/linked ]] || fail "the record is not empty"

# The home itself stays when its folders go.
export HOME=$PWD/bare
mkdir "$HOME"
switch .config/foo/config.toml "$one"
switch
absent .config
[[ -d $HOME ]] || fail "the home itself was removed"
