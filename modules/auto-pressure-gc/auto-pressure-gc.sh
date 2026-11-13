# shellcheck shell=bash
state_file="${STATE_DIRECTORY:?}/filesystem-state"

read_filesystem_usage() {
  local size used available percent

  read -r size used available percent < <(
    df --block-size=1 --output=size,used,avail,pcent /nix/store | tail -n 1
  )
  percent="${percent%%%}"

  if [[ ! "$size" =~ ^[0-9]+$ ]] ||
     [[ ! "$used" =~ ^[0-9]+$ ]] ||
     [[ ! "$available" =~ ^[0-9]+$ ]] ||
     [[ ! "$percent" =~ ^[0-9]+$ ]]; then
    echo "Could not determine /nix/store filesystem utilization" >&2
    return 1
  fi

  printf '%s %s %s %s\n' "$size" "$used" "$available" "$percent"
}

above_water_mark() {
  local used=$1 available=$2 water_percent=$3
  (( 100 * used >= water_percent * (used + available) ))
}

bytes_to_low_water() {
  local used=$1 available=$2
  local numerator

  # GNU df's percentage is used / (used + available), without reserved blocks; solve 100 * (used - freed) <= LOW_WATER_PERCENT * (used + available).
  numerator=$((
    (100 - LOW_WATER_PERCENT) * used -
    LOW_WATER_PERCENT * available
  ))
  printf '%s\n' "$(( (numerator + 99) / 100 ))"
}

read -r size used available percent < <(read_filesystem_usage)

if ! above_water_mark "$used" "$available" "$HIGH_WATER_PERCENT"; then
  echo "Disk utilization is $percent% (high water: $HIGH_WATER_PERCENT%); no garbage collection needed"
  exit 0
fi

# After a collection that missed low water, rescanning the same roots is futile; like Nix's own auto-GC, wait until available space falls by 3%.
previous_size=0
available_after_collection=0
if [[ -r "$state_file" ]] && read -r previous_size available_after_collection < "$state_file" &&
   [[ "$previous_size" =~ ^[0-9]+$ ]] &&
   [[ "$available_after_collection" =~ ^[0-9]+$ ]] &&
   (( size == previous_size )) &&
   (( available * 100 > available_after_collection * 97 )); then
  echo "Disk utilization is $percent%, but available space has not fallen by 3% since the previous garbage collection; skipping"
  exit 0
fi

pass=1
while (( pass <= MAXIMUM_PASSES )); do
  requested_bytes="$(bytes_to_low_water "$used" "$available")"
  if (( requested_bytes <= 0 )); then
    break
  fi

  echo "Disk utilization is $percent% (high water: $HIGH_WATER_PERCENT%); pass $pass is requesting at least $requested_bytes bytes to target $LOW_WATER_PERCENT%"
  nix-collect-garbage --max-freed "$requested_bytes"

  read -r final_size final_used final_available final_percent < <(read_filesystem_usage)
  progress=$(( final_available - available ))

  size=$final_size
  used=$final_used
  available=$final_available
  percent=$final_percent

  if ! above_water_mark "$used" "$available" "$LOW_WATER_PERCENT"; then
    break
  fi

  if (( progress < MINIMUM_PROGRESS_BYTES )); then
    echo "Garbage collection made less than $MINIMUM_PROGRESS_BYTES bytes of filesystem progress; suppressing another scan until available space falls by 3%" >&2
    break
  fi

  pass=$((pass + 1))
done

printf '%s %s\n' "$size" "$available" > "$state_file.tmp"
mv "$state_file.tmp" "$state_file"

if above_water_mark "$used" "$available" "$HIGH_WATER_PERCENT"; then
  echo "Garbage collection completed with $used of $size bytes used ($percent%), but utilization remains above the high-water mark; it will retry after available space falls by 3%" >&2
else
  echo "Garbage collection completed with $used of $size bytes used ($percent%)"
fi
