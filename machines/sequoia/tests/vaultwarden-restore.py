import json

url = f"http://127.0.0.1:{port}"
email = "restore-test@example.com"
# Clients send a hash of the master password, which the server only compares, so any string stands in for it.
password_hash = "restore-test"


def post_json(path, body, curl_options=""):
    return sequoia.succeed(f"curl -fsS --json '{json.dumps(body)}' {url}{path} {curl_options}")


def wait_until_alive():
    sequoia.wait_until_succeeds(f"curl -fsS {url}/alive")


start_all()
sequoia.wait_for_unit("vaultwarden.service")
wait_until_alive()

with subtest("an account the admin invites registers and opens a session"):
    sequoia.succeed(f"curl -fsS --cookie-jar /tmp/admin --data-urlencode token@{admin_token} {url}/admin")
    post_json("/admin/invite", {"email": email}, "--cookie /tmp/admin")
    token = json.loads(post_json("/identity/accounts/register/send-verification-email", {"email": email}))
    post_json(
        "/identity/accounts/register/finish",
        {
            "email": email,
            "emailVerificationToken": token,
            "masterPasswordHash": password_hash,
            "key": "restore-test",
            "kdf": 0,
            "kdfIterations": 600000,
        },
    )
    session = json.loads(
        sequoia.succeed(
            f"curl -fsS {url}/identity/connect/token -d grant_type=password -d client_id=web"
            " --data-urlencode 'scope=api offline_access' -d device_type=14 -d device_identifier=restore-test"
            f" -d device_name=restore-test --data-urlencode username={email} -d password={password_hash}"
        )
    )
    authorization = f"-H 'Authorization: Bearer {session['access_token']}'"
    # Answers only while the account and its device are in the database and the key that signed the session is on disk.
    profile = f"curl -fsS {authorization} {url}/api/accounts/profile"
    assert json.loads(sequoia.succeed(profile))["email"] == email

with subtest("the unit the timer starts takes one snapshot of the state's folders"):
    unit = sequoia.succeed(f"systemctl show --property=Triggers --value {timer}").strip()
    sequoia.succeed(f"systemctl start {unit}")
    snapshots = json.loads(sequoia.succeed(list_backups))
    assert [snapshot["paths"] for snapshot in snapshots] == [folders], snapshots

with subtest("without its data and the copy the backup took, Vaultwarden no longer knows the session"):
    sequoia.succeed("systemctl stop vaultwarden.service")
    sequoia.succeed(f"rm -rf {data_dir} {' '.join(folders)}")
    sequoia.succeed("systemctl start vaultwarden.service")
    wait_until_alive()
    sequoia.fail(profile)

with subtest("restoring the snapshot as clan backups restore does brings the account and its session back"):
    # clan backups restore runs these on the machine for each state, with NAME and FOLDERS set.
    env = f"NAME={snapshots[0]['name']} FOLDERS={':'.join(folders)}"
    for command in [pre_restore, restore, post_restore]:
        sequoia.succeed(f"{env} {command}")
        # The worst case of clan's SSH round trips between steps: a server one step starts is up before the next runs.
        sequoia.wait_until_succeeds(f"! systemctl -q is-active vaultwarden.service || curl -fsS {url}/alive")
    sequoia.succeed(f"curl -fsS {url}/alive")
    assert json.loads(sequoia.succeed(profile))["email"] == email

with subtest("what Vaultwarden saves after the restore outlasts a restart"):
    created = json.loads(post_json("/api/folders", {"name": "restore-test"}, authorization))
    sequoia.succeed("systemctl restart vaultwarden.service")
    wait_until_alive()
    saved = json.loads(sequoia.succeed(f"curl -fsS {authorization} {url}/api/folders"))["data"]
    assert [folder["id"] for folder in saved] == [created["id"]], saved
