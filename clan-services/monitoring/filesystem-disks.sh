# shellcheck shell=bash
output_file=$1

temporary_file=$(mktemp "$output_file.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

{
  echo '# HELP node_filesystem_disk_info The physical disk under a mounted filesystem device, through partitions, LUKS and LVM.'
  echo '# TYPE node_filesystem_disk_info gauge'
  findmnt --list --noheadings --nofsroot --output SOURCE | sort -u | while read -r device; do
    if [ -b "$device" ]; then
      lsblk --inverse --list --noheadings --output NAME,TYPE "$device" | while read -r name type; do
        if [ "$type" = disk ]; then
          echo "node_filesystem_disk_info{device=\"$device\",disk=\"$name\"} 1"
        fi
      done
    fi
  done | sort -u
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
