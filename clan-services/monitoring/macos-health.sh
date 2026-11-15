# shellcheck shell=bash
output_file=$1

disk=disk0
temporary_file=$(mktemp "$output_file.XXXXXX")
report=$(mktemp)
trap 'rm -f "$temporary_file" "$report"' EXIT

# smartctl's exit status is a bit mask; bits 0 and 1 mean it read nothing. Apple's controller
# rejects the request for its error log, which sets bit 2, and the rest of the report is complete.
status=0
smartctl --json --all "$disk" > "$report" || status=$?
if (( status & 3 )); then
  echo "smartctl could not read $disk: exit status $status" >&2
  exit 1
fi

model=$(jq --raw-output '.model_name' "$report")
passed=$(jq 'if .smart_status.passed then 1 else 0 end' "$report")
temperature=$(jq '.temperature.current' "$report")
percentage_used=$(jq '.nvme_smart_health_information_log.percentage_used' "$report")
media_errors=$(jq '.nvme_smart_health_information_log.media_errors' "$report")
pressure_level=$(/usr/sbin/sysctl -n kern.memorystatus_vm_pressure_level)
cpu_temperature=$(macmon pipe --samples 1 | jq '.temp.cpu_temp_avg')
# Empty on a Mac without a battery.
battery_health=$(/usr/sbin/system_profiler -json SPPowerDataType | jq '.SPPowerDataType[].sppower_battery_health_info.sppower_battery_health_maximum_capacity // empty | rtrimstr("%") | tonumber / 100')

# The drive's metrics have the names and labels smartctl_exporter gives them on Linux.
{
  echo '# HELP smartctl_device The drive and its model.'
  echo '# TYPE smartctl_device gauge'
  echo "smartctl_device{device=\"$disk\",model_name=\"$model\"} 1"
  echo '# HELP smartctl_device_smart_status 1 if the drive passed its SMART self-assessment.'
  echo '# TYPE smartctl_device_smart_status gauge'
  echo "smartctl_device_smart_status{device=\"$disk\"} $passed"
  echo '# HELP smartctl_device_temperature The drive temperature in degrees Celsius.'
  echo '# TYPE smartctl_device_temperature gauge'
  echo "smartctl_device_temperature{device=\"$disk\",temperature_type=\"current\"} $temperature"
  echo '# HELP smartctl_device_percentage_used The share of its rated endurance the drive has used.'
  echo '# TYPE smartctl_device_percentage_used gauge'
  echo "smartctl_device_percentage_used{device=\"$disk\"} $percentage_used"
  echo '# HELP smartctl_device_media_errors Unrecovered data integrity errors.'
  echo '# TYPE smartctl_device_media_errors gauge'
  echo "smartctl_device_media_errors{device=\"$disk\"} $media_errors"
  echo '# HELP macos_memory_pressure_level The memory pressure level: 1 normal, 2 warning, 4 critical.'
  echo '# TYPE macos_memory_pressure_level gauge'
  echo "macos_memory_pressure_level $pressure_level"
  echo '# HELP macos_cpu_temperature_celsius The average temperature of the CPU cores.'
  echo '# TYPE macos_cpu_temperature_celsius gauge'
  echo "macos_cpu_temperature_celsius $cpu_temperature"
  if [[ -n $battery_health ]]; then
    echo '# HELP macos_battery_health_ratio The full capacity of the battery as a share of its design capacity.'
    echo '# TYPE macos_battery_health_ratio gauge'
    echo "macos_battery_health_ratio $battery_health"
  fi
} > "$temporary_file"

chmod 0644 "$temporary_file"
mv "$temporary_file" "$output_file"
