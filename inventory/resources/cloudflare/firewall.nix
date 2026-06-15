# Cloudflare edge policy by hostname.
{
  hosts = {
    "llm.decio.us" = {
      customRules = [
        {
          description = "LLM API: block non-API paths";
          action = "block";
          expression = ''not starts_with(http.request.uri.path, "/v1/")'';
        }
        {
          description = "LLM API: block unexpected methods";
          action = "block";
          paths = [ "/v1/" ];
          expression = ''not (http.request.method in {"GET" "POST" "OPTIONS"})'';
        }
      ];

      # High enough for normal Pi/coding-agent use, low enough to stop runaway loops.
      rateLimits = [
        {
          description = "LLM API: throttle runaway clients";
          paths = [ "/v1/" ];
          methods = [
            "GET"
            "POST"
            "OPTIONS"
          ];
          period = 10;
          requestsPerPeriod = 30;
          mitigationTimeout = 10;
        }
      ];
    };
  };
}
