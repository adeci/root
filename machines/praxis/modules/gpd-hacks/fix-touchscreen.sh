# shellcheck shell=bash
for attempt in 1 2; do
  modprobe -r i2c_hid_acpi 2> /dev/null || true
  sleep 2
  modprobe i2c_hid_acpi || true
  sleep 2

  # No grep -q: an early exit would fail the pipeline.
  if grep -A8 'NVTK0603' /proc/bus/input/devices | grep 'PROP=1' > /dev/null; then
    echo "Touchscreen restored (attempt $attempt)"
    exit 0
  fi
done

echo "Touchscreen not restored after 2 attempts" >&2
exit 1
