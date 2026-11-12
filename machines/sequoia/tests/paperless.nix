# sequoia's Paperless end to end: the printer's FTP upload, OCR, and AI filing switched on and off against a mock LLM; on demand, not a check.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  inherit (self.resources.homelan) hosts vlans;
  prefixLength = lib.toInt (lib.last (lib.splitString "/" vlans.trusted.cidr));

  llmPort = 8199;

  # Runs a clan vars generator from the modules.
  generate =
    name: generator:
    pkgs.runCommand "vars-${name}" { nativeBuildInputs = generator.runtimeInputs or [ ]; } ''
      set -euo pipefail
      mkdir -p "$out"
      ${generator.script}
    '';

  # Stands in for clan: accepts the modules' clan settings and points each vars file at its generator's output.
  clan =
    { lib, ... }:
    let
      inherit (lib) mkOption types;
      freeform = types.attrsOf types.anything;
    in
    {
      options.clan.core = {
        state = mkOption { type = freeform; };
        postgresql = mkOption { type = freeform; };
        vars.generators = mkOption {
          type = types.attrsOf (
            types.submodule (
              { name, config, ... }:
              let
                generated = generate name config;
              in
              {
                freeformType = freeform;
                options.files = mkOption {
                  type = types.attrsOf (
                    types.submodule (
                      { name, ... }:
                      {
                        freeformType = freeform;
                        options.path = mkOption {
                          type = types.str;
                          default = "${generated}/${name}";
                        };
                      }
                    )
                  );
                };
              }
            )
          );
        };
      };
    };

  # A utility bill dated in US order, scanned sideways and slightly skewed.
  scan =
    let
      lines = [
        "ACME POWER COMPANY"
        "Electricity statement"
        "Statement date: 03/04/2025"
        "Account number: 4417-2290-31"
        "Service address: 12 Example Street, Springfield"
        ""
        "Previous balance                                $84.20"
        "Payment received, thank you                     $84.20"
        "Balance forward                                  $0.00"
        ""
        "Delivery charges"
        "  Basic service charge                          $18.00"
        "  Distribution, 412 kWh at $0.0721              $29.71"
        "  System benefit charge                          $3.12"
        "Supply charges"
        "  Energy supply, 412 kWh at $0.1088             $44.83"
        "  Merchant function charge                       $1.97"
        ""
        "Current charges                                 $97.63"
        "Amount due                                      $97.63"
        "Please pay by 03/25/2025"
        ""
        "Your usage this period was 412 kWh over 29 days, an average"
        "of 14.2 kWh per day. Last year you used 455 kWh in the same"
        "period. Thank you for being a valued customer of Acme Power."
      ];
      drawLines = lib.concatImapStringsSep " " (
        i: line: "-annotate +250+${toString (250 + i * 110)} ${lib.escapeShellArg line}"
      ) lines;
    in
    # A Letter page at 300 dpi, rotated 90° plus 1.5° of skew.
    pkgs.runCommand "scan.pdf" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
      magick -size 2550x3300 xc:white -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSansMono.ttf \
        -pointsize 50 -fill black ${drawLines} \
        -background white -rotate 91.5 +repage -units PixelsPerInch -density 300 $out
    '';

  # Logs each request, holds its answer until /run/mock-llm/release exists, then files the bill.
  mockLlm = pkgs.writers.writePython3 "mock-llm" { } ''
    import json
    import os
    import time
    from http.server import BaseHTTPRequestHandler, HTTPServer

    REQUESTS = "/run/mock-llm/requests.jsonl"
    RELEASE = "/run/mock-llm/release"
    SUGGESTION = {
        "title": "Acme Power statement",
        "tags": ["Utilities"],
        "correspondents": ["Acme Power"],
        "document_types": ["Bill"],
        "dates": ["2025-02-28"],
    }


    def completion(request):
        """A chat completion calling the request's tool with SUGGESTION."""
        call = {
            "id": "call-0",
            "type": "function",
            "function": {
                "name": request["tools"][0]["function"]["name"],
                "arguments": json.dumps(SUGGESTION),
            },
        }
        message = {"role": "assistant", "content": None, "tool_calls": [call]}
        return {
            "id": "chatcmpl-0",
            "object": "chat.completion",
            "created": 0,
            "model": request["model"],
            "choices": [
                {"index": 0, "finish_reason": "tool_calls", "message": message},
            ],
        }


    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers["Content-Length"])
            request = json.loads(self.rfile.read(length))
            entry = {
                "path": self.path,
                "authorization": self.headers["Authorization"],
                "body": request,
            }
            with open(REQUESTS, "a") as log:
                log.write(json.dumps(entry) + "\n")
            while not os.path.exists(RELEASE):
                time.sleep(0.5)
            reply = json.dumps(completion(request)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(reply)))
            self.end_headers()
            self.wfile.write(reply)


    HTTPServer(("127.0.0.1", ${toString llmPort}), Handler).serve_forever()
  '';
in
pkgs.testers.runNixOSTest {
  name = "sequoia-paperless";
  node.specialArgs = { inherit self; };

  nodes.sequoia =
    { lib, pkgs, ... }:
    {
      imports = [
        clan
        self.modules.nixos.primary-user
        ../modules/paperless.nix
        ../modules/paperless-xerox-ingest.nix
      ];

      system.primaryUser = "alex";

      virtualisation = {
        memorySize = 4096;
        cores = 2;
      };
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = hosts.sequoia.ip;
          inherit prefixLength;
        }
      ];
      # The test talks to Paperless directly; nginx would need the real wildcard certificate.
      services.nginx.enable = lib.mkForce false;
      environment.systemPackages = [
        pkgs.jq
        pkgs.poppler-utils
      ];

      systemd.services.mock-llm = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = mockLlm;
          RuntimeDirectory = "mock-llm";
        };
      };

      # AI filing switched on; the test switches into this and back out.
      specialisation.ai.configuration.paperlessAi = {
        enable = true;
        endpoint = "http://127.0.0.1:${toString llmPort}/v1";
        model = "test-model";
      };
    };

  nodes.printer =
    { lib, nodes, ... }:
    {
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = hosts.printer.ip;
          inherit prefixLength;
        }
        # A second address, standing in for any other LAN client.
        {
          address = vlans.trusted.dhcpPool.start;
          inherit prefixLength;
        }
      ];
      environment.etc.ftp-password.source =
        nodes.sequoia.clan.core.vars.generators.paperless-xerox-ingest.files.ftp-password.path;
    };

  testScript =
    { nodes, ... }:
    ''
      import json

      # Paperless' numbers for the workflow trigger and action types used here.
      DOCUMENT_ADDED, DOCUMENT_UPDATED = 2, 3
      REMOVAL, APPLY_AI_SUGGESTIONS = 2, 8

      api = "curl -fsS -u alex:$(cat ${nodes.sequoia.services.paperless.passwordFile}) http://127.0.0.1:28981/api"
      ftp = "ftp://paperless-upload:$(cat /etc/ftp-password)@${hosts.sequoia.ip}"
      consume = "${nodes.sequoia.services.paperless.consumptionDir}"


      def get(path):
          return json.loads(sequoia.succeed(f"{api}{path}"))


      def patch(path, body):
          sequoia.succeed(f"{api}{path} -X PATCH -H 'Content-Type: application/json' -d '{json.dumps(body)}'")


      def tag_names(doc):
          return sorted(get(f"/tags/{tag}/")["name"] for tag in doc["tags"])


      def llm_requests():
          return [json.loads(line) for line in sequoia.succeed("cat /run/mock-llm/requests.jsonl").splitlines()]


      def upright(pdf):
          """Whether the PDF's first page shows in portrait."""
          info = {}
          for line in sequoia.succeed(f"pdfinfo {pdf}").splitlines():
              key, _, value = line.partition(":")
              info[key] = value.split()
          width, height = float(info["Page size"][0]), float(info["Page size"][2])
          return (width < height) != (int(info["Page rot"][0]) % 180 == 90)


      def tags():
          return {tag["name"]: tag for tag in get("/tags/")["results"]}


      def workflows():
          return {flow["name"]: flow for flow in get("/workflows/")["results"]}


      def switch_to(system):
          """Switches sequoia's configuration live and waits until Paperless answers again."""
          sequoia.succeed(f"{system}/bin/switch-to-configuration test")
          for unit in ["paperless-web", "paperless-task-queue", "paperless-consumer", "paperless-workflows"]:
              sequoia.wait_for_unit(f"{unit}.service")
          sequoia.wait_until_succeeds(f"{api}/documents/", timeout=300)


      start_all()
      for unit in ["paperless-web", "paperless-task-queue", "paperless-consumer", "paperless-workflows", "vsftpd", "mock-llm"]:
          sequoia.wait_for_unit(f"{unit}.service")
      sequoia.wait_until_succeeds(f"{api}/documents/", timeout=300)
      users = {user["username"]: user["id"] for user in get("/users/")["results"]}

      with subtest("without AI, new documents get an owner and the inbox, and nothing else"):
          inbox = tags()["Inbox"]
          assert inbox["is_inbox_tag"] and "Classify" not in tags(), tags()
          assert list(workflows()) == ["Inbox and owner"], workflows()
          flow = workflows()["Inbox and owner"]
          assert [trigger["type"] for trigger in flow["triggers"]] == [DOCUMENT_ADDED], flow
          [assign] = flow["actions"]
          assert assign["assign_owner"] == users["alex"] and assign["assign_tags"] == [inbox["id"]], assign

      with subtest("only the printer reaches the FTP server"):
          printer.fail("curl -fsS --connect-timeout 5 --interface ${vlans.trusted.dhcpPool.start} ftp://${hosts.sequoia.ip}/")

      with subtest("the printer's sideways scan is consumed upright, OCRed and dated month first, without asking any model"):
          printer.succeed(f"curl -fsS -T ${scan} {ftp}/scan.pdf")
          sequoia.wait_until_succeeds(f"{api}/documents/ | jq -e '.count == 1'", timeout=600)
          [doc] = get("/documents/")["results"]
          content = " ".join(doc["content"].split())
          for phrase in ["ACME POWER COMPANY", "Statement date: 03/04/2025", "Amount due", "$97.63"]:
              assert phrase in content, (phrase, content)
          assert doc["created"] == "2025-03-04", doc["created"]
          assert doc["tags"] == [inbox["id"]] and doc["owner"] == users["alex"], doc
          sequoia.succeed(f"{api}/documents/{doc['id']}/download/?original=true -o /tmp/original.pdf")
          sequoia.succeed(f"{api}/documents/{doc['id']}/download/ -o /tmp/archive.pdf")
          assert not upright("/tmp/original.pdf") and upright("/tmp/archive.pdf")
          sequoia.succeed(f"test -z \"$(ls -A {consume})\"")
          sequoia.succeed("test ! -s /run/mock-llm/requests.jsonl")

      with subtest("a scan sent twice is dropped as a duplicate"):
          printer.succeed(f"curl -fsS -T ${scan} {ftp}/scan-again.pdf")
          sequoia.wait_until_succeeds(f"test -z \"$(ls -A {consume})\"", timeout=120)
          assert get("/documents/")["count"] == 1

      switch_to("/run/booted-system/specialisation/ai")

      with subtest("switching AI on adds the Classify tag and the AI workflow after the inbox one"):
          classify = tags()["Classify"]
          assert not classify["is_inbox_tag"], classify
          flows = workflows()
          assert flows["Inbox and owner"]["order"] < flows["AI classification"]["order"], flows
          for flow in flows.values():
              added, updated = sorted(flow["triggers"], key=lambda trigger: trigger["type"])
              assert added["type"] == DOCUMENT_ADDED and updated["type"] == DOCUMENT_UPDATED, flow
              assert updated["filter_has_tags"] == [classify["id"]], flow
          actions = {action["type"]: action for action in flows["AI classification"]["actions"]}
          suggest, done = actions[APPLY_AI_SUGGESTIONS], actions[REMOVAL]
          assert suggest["ai_create_missing"] and suggest["ai_overwrite_existing"], suggest
          assert sorted(suggest["ai_suggestion_fields"]) == ["correspondent", "created", "document_type", "tags", "title"]
          assert done["remove_tags"] == [classify["id"]], done

      with subtest("a Classify-tagged document goes to the configured model without a key, and its answer is applied"):
          patch(f"/documents/{doc['id']}/", {"title": "scan", "tags": [classify["id"]]})
          sequoia.wait_until_succeeds("test -s /run/mock-llm/requests.jsonl", timeout=120)
          [request] = llm_requests()
          assert request["path"] == "/v1/chat/completions", request["path"]
          # Paperless' placeholder when no key is configured.
          assert request["authorization"] == "Bearer fake", request["authorization"]
          assert request["body"]["model"] == "test-model", request["body"]["model"]
          assert "ACME POWER" in json.dumps(request["body"]["messages"]), request["body"]["messages"]
          sequoia.succeed("touch /run/mock-llm/release")
          sequoia.wait_until_succeeds(
              f"{api}/documents/{doc['id']}/ | jq -e '.title == \"Acme Power statement\" and (.tags | length) == 2'",
              timeout=120,
          )
          doc = get(f"/documents/{doc['id']}/")
          assert doc["created"] == "2025-02-28", doc["created"]
          assert get(f"/correspondents/{doc['correspondent']}/")["name"] == "Acme Power", doc
          assert get(f"/document_types/{doc['document_type']}/")["name"] == "Bill", doc
          assert tag_names(doc) == ["Inbox", "Utilities"], doc

      with subtest("edits in the UI hold until the declaration changes"):
          flow = workflows()["AI classification"]
          patch(f"/workflows/{flow['id']}/", {"enabled": False})
          sequoia.succeed("systemctl restart paperless-workflows")
          assert not get(f"/workflows/{flow['id']}/")["enabled"]
          sequoia.succeed("rm ${nodes.sequoia.services.paperless.dataDir}/workflows-applied")
          sequoia.succeed("systemctl restart paperless-workflows")
          assert get(f"/workflows/{flow['id']}/")["enabled"]

      switch_to("/run/booted-system")

      with subtest("switching AI off removes the AI workflow and the Classify trigger"):
          assert list(workflows()) == ["Inbox and owner"], workflows()
          flow = workflows()["Inbox and owner"]
          assert [trigger["type"] for trigger in flow["triggers"]] == [DOCUMENT_ADDED], flow
    '';
}
