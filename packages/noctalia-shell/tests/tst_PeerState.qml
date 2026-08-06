import QtQuick
import QtTest
import "../plugins/tailscale/PeerState.js" as PeerState

TestCase {
  name: "PeerState"

  function test_tailnet_suffix() {
    compare(PeerState.tailnetSuffix("praxis.cymric-daggertooth.ts.net."),
            "cymric-daggertooth.ts.net.");
    compare(PeerState.tailnetSuffix(""), "");
  }

  function test_external_tailnet_prefers_dns_tailnet() {
    var selfDns = "praxis.cymric-daggertooth.ts.net.";
    verify(!PeerState.isExternalTailnet({
      "DNSName": "bramble.cymric-daggertooth.ts.net.",
      "UserID": 1
    }, 1, selfDns));
    verify(PeerState.isExternalTailnet({
      "DNSName": "aspen1.bison-tailor.ts.net.",
      "UserID": 1
    }, 1, selfDns));
  }

  function test_external_tailnet_falls_back_to_owner() {
    verify(!PeerState.isExternalTailnet({ "UserID": 1 }, 1, ""));
    verify(PeerState.isExternalTailnet({ "UserID": 2 }, 1, ""));
  }

  function test_peer_snapshot_ignores_input_order_but_detects_state_changes() {
    var online = {
      "DNSName": "a.tailnet.ts.net.",
      "HostName": "a",
      "TailscaleIPs": ["100.64.0.1"],
      "Online": true,
      "PrimaryRoutes": ["10.20.0.0/24", "10.10.0.0/24"]
    };
    var offline = {
      "DNSName": "b.tailnet.ts.net.",
      "HostName": "b",
      "TailscaleIPs": ["100.64.0.2"],
      "Online": false
    };
    var first = PeerState.peerListSnapshot([online, offline]);
    compare(first, PeerState.peerListSnapshot([offline, online]));
    compare(first, PeerState.peerListSnapshot([
      Object.assign({}, online, { "PrimaryRoutes": ["10.10.0.0/24", "10.20.0.0/24"] }),
      offline
    ]));
    verify(first !== PeerState.peerListSnapshot([
      Object.assign({}, online, { "Online": false }),
      offline
    ]));
  }

  function test_large_json_ids_are_preserved_for_owner_lookup() {
    var raw = '{"Self":{"UserID":47256370424925063},' +
      '"Peer":{"node":{"UserID":47256370424925065}},' +
      '"User":{"47256370424925063":{"DisplayName":"Alex"},' +
      '"47256370424925065":{"DisplayName":"Britton"}}}';
    var parsed = JSON.parse(PeerState.preserveUserIds(raw));
    compare(parsed.Self.UserID, "47256370424925063");
    compare(parsed.Peer.node.UserID, "47256370424925065");
    compare(PeerState.ownerName(parsed.User, parsed.Peer.node.UserID), "Britton");
  }
}
