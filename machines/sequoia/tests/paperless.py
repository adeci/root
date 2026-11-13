import json

# Paperless' numbers for the workflow trigger and action types used here.
DOCUMENT_ADDED, DOCUMENT_UPDATED = 2, 3
REMOVAL, APPLY_AI_SUGGESTIONS = 2, 8

api = f"curl -fsS -u alex:$(cat {password_file}) http://127.0.0.1:{port}/api"
ftp = f"ftp://paperless-upload:$(cat /etc/ftp-password)@{sequoia_ip}"


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
    printer.fail(f"curl -fsS --connect-timeout 5 --interface {other_client_ip} ftp://{sequoia_ip}/")

with subtest("the printer's sideways scan is consumed upright, OCRed and dated month first, without asking any model"):
    printer.succeed(f"curl -fsS -T {scan} {ftp}/scan.pdf")
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
    printer.succeed(f"curl -fsS -T {scan} {ftp}/scan-again.pdf")
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
    sequoia.succeed(f"rm {data_dir}/workflows-applied")
    sequoia.succeed("systemctl restart paperless-workflows")
    assert get(f"/workflows/{flow['id']}/")["enabled"]

switch_to("/run/booted-system")

with subtest("switching AI off removes the AI workflow and the Classify trigger"):
    assert list(workflows()) == ["Inbox and owner"], workflows()
    flow = workflows()["Inbox and owner"]
    assert [trigger["type"] for trigger in flow["triggers"]] == [DOCUMENT_ADDED], flow
