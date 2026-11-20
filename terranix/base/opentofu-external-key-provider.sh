# shellcheck shell=bash
# Always return the decryption key: states saved before metadata existed need it.
echo '{"magic":"OpenTofu-External-Key-Provider","version":1}'
cat >/dev/null || true
PASSPHRASE=$(clan secrets get tf-passphrase)
jq -n --arg key "$PASSPHRASE" '{"keys":{"encryption_key":($key|@base64),"decryption_key":($key|@base64)},"meta":{"external_data":{}}}'
