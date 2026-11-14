# Queries over Linux and macOS alike, given label matchers.
{
  # Linux reports what is available; on a Mac, Activity Monitor's "Memory Used" is app memory, wired and compressed.
  memoryUsed = matchers: ''
    100 * (1 - node_memory_MemAvailable_bytes{${matchers}} / node_memory_MemTotal_bytes{${matchers}})
    or 100 * (node_memory_internal_bytes{${matchers}} - node_memory_purgeable_bytes{${matchers}} + node_memory_wired_bytes{${matchers}} + node_memory_compressed_bytes{${matchers}}) / node_memory_total_bytes{${matchers}}
  '';
}
