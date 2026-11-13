{ lib, pkgs }:
let
  yaml = pkgs.formats.yaml { };

  rules = import ../rules.nix {
    inherit lib;
    alwaysOn = [ "server" ];
    machineRules = { };
  };
  rulesFile = yaml.generate "fleet-rules.yml" rules.fleet;

  ruleTests = yaml.generate "fleet-rules-test.yml" {
    rule_files = [ "${rulesFile}" ];
    evaluation_interval = "1m";
    tests = import ./rule-tests.nix;
  };

  alertWithoutSeverity = import ../rules.nix {
    inherit lib;
    alwaysOn = [ ];
    machineRules.server = [
      {
        alert = "Unrouted";
        expr = "vector(1)";
      }
    ];
  };
  rejectsAlertWithoutSeverity =
    !(builtins.tryEval (builtins.deepSeq alertWithoutSeverity.machines.groups null)).success;

  alertmanagerConfig = yaml.generate "alertmanager.yml" (
    import ../alertmanager.nix {
      inherit lib;
      webhookUrl = "http://127.0.0.1:8000/hook";
      timeZone = "America/New_York";
      quietHours = {
        start = "22:00";
        end = "08:00";
      };
    }
  );

  bridgeConfig = yaml.generate "alertmanager-ntfy.yml" (
    import ../ntfy-bridge.nix {
      inherit lib;
      listenAddress = "127.0.0.1:8000";
      baseUrl = "http://127.0.0.1:8001";
      topic = "alerts";
      clickUrl = "https://grafana.example/d/fleet";
    }
  );
in
assert lib.assertMsg rejectsAlertWithoutSeverity "rules.nix accepts an alert without a severity";
pkgs.runCommand "monitoring-tests"
  {
    nativeBuildInputs = [
      pkgs.alertmanager-ntfy
      pkgs.prometheus-alertmanager
      pkgs.prometheus.cli
      pkgs.python3
    ];
  }
  ''
    promtool check rules ${rulesFile}
    promtool test rules ${ruleTests}

    amtool check-config ${alertmanagerConfig}
    for severity in critical warning; do
      amtool config routes test --config.file=${alertmanagerConfig} --verify.receivers=ntfy severity=$severity
    done

    python3 ${./ntfy-bridge.py} ${bridgeConfig}

    touch $out
  ''
