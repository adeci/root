# shellcheck shell=bash
state_file=$STATE_DIRECTORY/filesystem-state

read_filesystem_usage() {
  read -r size used available percent < <(
    df --block-size=1 --output=size,used,avail,pcent /nix/store | tail -n 1
  )
}

above_high_water() {
  (( 100 * used >= HIGH_WATER_PERCENT * (used + available) ))
}

read_filesystem_usage

if ! above_high_water; then
  echo "Disk utilization is $percent (high water: $HIGH_WATER_PERCENT%); no garbage collection needed"
  rm -f "$state_file"
  exit 0
fi

# The last GC freed almost nothing: wait for free space to drop 3%, like Nix's own auto-GC.
if [[ -e $state_file ]] && read -r previous_size previous_available < "$state_file" &&
   (( size == previous_size && 100 * available > 97 * previous_available )); then
  echo "Disk utilization is $percent, but free space hasn't dropped 3% since the last GC; skipping"
  exit 0
fi

# df's % is used/(used+available): solve 100*(used-freed) <= LOW_WATER_PERCENT*(used+available).
requested_bytes=$(( ((100 - LOW_WATER_PERCENT) * used - LOW_WATER_PERCENT * available + 99) / 100 ))
echo "Disk utilization is $percent (high water: $HIGH_WATER_PERCENT%); requesting at least $requested_bytes bytes to target $LOW_WATER_PERCENT%"
nix-collect-garbage --max-freed "$requested_bytes"

available_before=$available
read_filesystem_usage
echo "Garbage collection completed with $used of $size bytes used ($percent)"

if (( available - available_before < MINIMUM_PROGRESS_BYTES )) && above_high_water; then
  echo "GC freed less than $MINIMUM_PROGRESS_BYTES bytes; waiting for free space to drop 3%" >&2
  echo "$size $available" > "$state_file"
else
  rm -f "$state_file"
fi
