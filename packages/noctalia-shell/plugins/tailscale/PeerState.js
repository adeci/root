function preserveUserIds(jsonText) {
  return String(jsonText || "").replace(/("UserID"\s*:\s*)(\d+)/g, '$1"$2"');
}

function tailnetSuffix(dnsName) {
  if (!dnsName) return "";
  var firstDot = dnsName.indexOf(".");
  return firstDot === -1 ? "" : dnsName.substring(firstDot + 1);
}

function isExternalTailnet(peer, selfUserId, selfDnsName) {
  var peerTailnet = tailnetSuffix(peer?.DNSName || "");
  var selfTailnet = tailnetSuffix(selfDnsName || "");
  if (peerTailnet && selfTailnet) return peerTailnet !== selfTailnet;
  return peer?.UserID !== undefined && peer.UserID !== selfUserId;
}

function ownerName(users, userId) {
  var owner = users?.[String(userId)];
  return owner?.DisplayName || owner?.LoginName || "";
}

function sortedStrings(values) {
  return (values || [])
    .map(function (value) {
      return String(value);
    })
    .sort();
}

function peerListSnapshot(peers) {
  var rows = (peers || []).map(function (peer) {
    return {
      dnsName: peer.DNSName || "",
      hostName: peer.HostName || "",
      ips: sortedStrings(peer.TailscaleIPs),
      online: peer.Online === true,
      os: peer.OS || "",
      tags: sortedStrings(peer.Tags),
      externalTailnet: peer.ExternalTailnet === true,
      ownerName: peer.OwnerName || "",
      primaryRoutes: sortedStrings(peer.PrimaryRoutes),
      exitNodeOption: peer.ExitNodeOption === true,
      exitNode: peer.ExitNode === true,
    };
  });
  rows.sort(function (a, b) {
    var aKey = a.dnsName + "\u0000" + a.hostName + "\u0000" + a.ips.join(",");
    var bKey = b.dnsName + "\u0000" + b.hostName + "\u0000" + b.ips.join(",");
    return aKey < bKey ? -1 : aKey > bKey ? 1 : 0;
  });
  return JSON.stringify(rows);
}
