{
  "devblog" = {
    module = {
      name = "@adeci/siteup";
      input = "self";
    };
    roles.app = {
      machines.sequoia = {
        settings = {
          name = "devblog";
          flakeRef = "devblog";
          args = [
            "--port"
            "4444"
          ];
        };
      };
    };
  };

  "trader" = {
    module = {
      name = "@adeci/siteup";
      input = "self";
    };
    roles.app = {
      machines.sequoia = {
        settings = {
          name = "trader";
          flakeRef = "trader-rs";
          port = 5555;
          secrets = [
            "TRADIER_API_KEY"
            "FINNHUB_API_KEY"
            "FMP_API_KEY"
            "ANTHROPIC_API_KEY"
            "DISCORD_WEBHOOK_URL"
            "DASHBOARD_PASSWORD"
          ];
        };
      };
    };
  };
}
