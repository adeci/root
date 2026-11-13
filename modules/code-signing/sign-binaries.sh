# shellcheck shell=bash
# The key is made on this Mac once and never leaves it.
install -d -m 700 "$STATE_DIRECTORY"
if [ ! -s "$STATE_DIRECTORY/cert.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
    -subj "/CN=$(/bin/hostname -s) code signing" \
    -addext basicConstraints=critical,CA:false \
    -addext keyUsage=critical,digitalSignature \
    -addext extendedKeyUsage=critical,codeSigning \
    -keyout "$STATE_DIRECTORY/key.pem" -out "$STATE_DIRECTORY/cert.pem" 2>/dev/null
fi
fingerprint=$(openssl x509 -noout -fingerprint -sha1 -in "$STATE_DIRECTORY/cert.pem" | cut -d= -f2 | tr -d :)

keychain=
sign() {
  name=$1 source=$2 path=$3 identifier=$4
  if [ -x "$path" ] && [ "$(cat "$STATE_DIRECTORY/$name.source" 2>/dev/null)" = "$source" ]; then
    return
  fi
  if [ -z "$keychain" ]; then
    keychain=$(mktemp -d)/signing.keychain
    # codesign takes identities only from a keychain; this one lives for the run.
    openssl pkcs12 -export -legacy -inkey "$STATE_DIRECTORY/key.pem" -in "$STATE_DIRECTORY/cert.pem" -passout pass:signing -out "$keychain.p12"
    /usr/bin/security create-keychain -p signing "$keychain"
    /usr/bin/security unlock-keychain -p signing "$keychain"
    /usr/bin/security import "$keychain.p12" -k "$keychain" -P signing -T /usr/bin/codesign >/dev/null
  fi
  echo "signing $name..."
  install -d "$(dirname "$path")"
  install -m 755 "$source" "$path.new"
  # Ad-hoc signatures change with every build, and macOS forgets privacy grants such as Accessibility with them.
  /usr/bin/codesign --force --keychain "$keychain" --sign "$fingerprint" --identifier "$identifier" "$path.new"
  mv -f "$path.new" "$path"
  echo "$source" > "$STATE_DIRECTORY/$name.source"
}

while [ "$#" -gt 0 ]; do
  sign "$1" "$2" "$3" "$4"
  shift 4
done

if [ -n "$keychain" ]; then
  /usr/bin/security delete-keychain "$keychain"
  rm -rf "$(dirname "$keychain")"
fi
