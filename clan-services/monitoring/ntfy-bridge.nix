# alertmanager-ntfy settings: severity picks the ntfy priority, and a resolution quietly replaces its alert's notification.
{
  lib,
  listenAddress,
  baseUrl,
  topic,
  clickUrl,
}:
{
  http.addr = listenAddress;
  ntfy = {
    baseurl = baseUrl;
    async = false;
    notification = {
      inherit topic;
      priority = ''status == "resolved" ? "min" : (labels.severity == "critical" ? "high" : "default")'';
      tags = [
        {
          tag = "rotating_light";
          condition = ''status == "firing" && labels.severity == "critical"'';
        }
        {
          tag = "warning";
          condition = ''status == "firing" && labels.severity == "warning"'';
        }
        {
          tag = "white_check_mark";
          condition = ''status == "resolved"'';
        }
      ];
      templates = {
        title = ''{{ if eq .Status "resolved" }}Resolved: {{ end }}{{ index .Annotations "summary" }}'';
        description = ''{{ index .Annotations "description" }}'';
        headers = {
          # ntfy replaces the notification that has the same sequence ID, so each alert keeps one.
          X-Sequence-ID = "{{ .Fingerprint }}";
        }
        // lib.optionalAttrs (clickUrl != null) { X-Click = clickUrl; };
      };
    };
  };
}
