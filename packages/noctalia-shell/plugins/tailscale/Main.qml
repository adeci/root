import QtQuick
import Quickshell
import qs.Commons
import Quickshell.Io
import qs.Services.UI
import "PeerState.js" as PeerState

Item {
  id: root

  property var pluginApi: null

  onPluginApiChanged: {
    if (pluginApi) {
      settingsVersion++;
    }
  }

  // Watch for settings changes (when pluginSettings object is replaced)
  property var settingsWatcher: pluginApi?.pluginSettings
  onSettingsWatcherChanged: {
    if (settingsWatcher) {
      settingsVersion++;
    }
  }

  property int settingsVersion: 0

  property int refreshInterval: _computeRefreshInterval()
  property bool compactMode: _computeCompactMode()
  property bool showIpAddress: _computeShowIpAddress()
  property bool showPeerCount: _computeShowPeerCount()

  function _computeRefreshInterval() {
    return pluginApi?.pluginSettings?.refreshInterval ?? 5000;
  }
  function _computeCompactMode() {
    return pluginApi?.pluginSettings?.compactMode ?? false;
  }
  function _computeShowIpAddress() {
    return pluginApi?.pluginSettings?.showIpAddress ?? true;
  }
  function _computeShowPeerCount() {
    return pluginApi?.pluginSettings?.showPeerCount ?? true;
  }

  onSettingsVersionChanged: {
    refreshInterval = _computeRefreshInterval();
    compactMode = _computeCompactMode();
    showIpAddress = _computeShowIpAddress();
    showPeerCount = _computeShowPeerCount();
    updateTimer.interval = refreshInterval;
  }

  property bool tailscaleInstalled: false
  property bool tailscaleRunning: false
  property string tailscaleIp: ""
  property string tailscaleStatus: ""
  property bool needsLogin: false
  property int peerCount: 0
  property bool isRefreshing: false
  property var _realPeerList: []
  property string _peerListSnapshot: "[]"
  property var exitNodeStatus: null

  readonly property var peerList: _realPeerList

  function setPeerList(peers) {
    var nextPeers = peers || [];
    var snapshot = PeerState.peerListSnapshot(nextPeers);
    if (snapshot === root._peerListSnapshot)
      return;
    root._peerListSnapshot = snapshot;
    root._realPeerList = nextPeers;
  }

  // Helper to filter IPv4 addresses from Tailscale (100.x.x.x range)
  function filterIPv4(ips) {
    if (!ips || !ips.length)
      return [];
    return ips.filter(ip => ip.startsWith("100."));
  }

  // Some devices (e.g. Android) report "localhost" as their HostName.
  // In that case, derive a meaningful name from the first label of DNSName.
  function resolveHostName(hostName, dnsName) {
    if (hostName && hostName.toLowerCase() !== "localhost")
      return hostName;
    if (!dnsName)
      return hostName;
    var label = dnsName.split(".")[0];
    return label || hostName;
  }

  // Extract the Tailscale short name from DNSName (e.g. "tp-g6.tail68e513.ts.net." → "tp-g6").
  // This is what `tailscale file cp` and other commands expect as a target.
  function tailscaleName(dnsName) {
    if (!dnsName) return ""
    return dnsName.split(".")[0] || ""
  }

  Process {
    id: whichProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode, exitStatus) {
      root.tailscaleInstalled = (exitCode === 0);
      root.isRefreshing = false;
      updateTailscaleStatus();
    }
  }

  Process {
    id: statusProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function (exitCode, exitStatus) {
      root.isRefreshing = false;
      var stdout = String(statusProcess.stdout.text || "").trim();
      var stderr = String(statusProcess.stderr.text || "").trim();

      if (exitCode === 0 && stdout && stdout.length > 0) {
        try {
          var data = JSON.parse(PeerState.preserveUserIds(stdout));
          root.tailscaleRunning = data.BackendState === "Running";
          root.needsLogin = data.BackendState === "NeedsLogin";

          if (root.needsLogin) {
            root.tailscaleIp = "";
            root.tailscaleStatus = "NeedsLogin";
            root.peerCount = 0;
            root.setPeerList([]);
            root.exitNodeStatus = null;
          } else if (root.tailscaleRunning && data.Self && data.Self.TailscaleIPs && data.Self.TailscaleIPs.length > 0) {
            root.tailscaleIp = filterIPv4(data.Self.TailscaleIPs)[0] || data.Self.TailscaleIPs[0];
            root.tailscaleStatus = "Connected";

            var peers = [];
            if (data.Peer) {
              for (var peerId in data.Peer) {
                var peer = data.Peer[peerId];
                var ipv4s = filterIPv4(peer.TailscaleIPs);
                peers.push({
                             "HostName": resolveHostName(peer.HostName, peer.DNSName),
                             "DNSName": peer.DNSName,
                             "TailscaleIPs": ipv4s,
                             "Online": peer.Online,
                             "OS": peer.OS,
                             "Tags": peer.Tags || [],
                             "ExternalTailnet": PeerState.isExternalTailnet(peer, data.Self.UserID, data.Self.DNSName),
                             "OwnerName": PeerState.ownerName(data.User, peer.UserID),
                             "PrimaryRoutes": peer.PrimaryRoutes || [],
                             "ExitNodeOption": peer.ExitNodeOption || false,
                             "ExitNode": peer.ExitNode || false
                           });
              }
            }
            root.setPeerList(peers);
            root.peerCount = peers.length;

            // Extract exit node status if present
            if (data.ExitNodeStatus) {
              root.exitNodeStatus = {
                "ID": data.ExitNodeStatus.ID || "",
                "Online": data.ExitNodeStatus.Online || false,
                "TailscaleIPs": data.ExitNodeStatus.TailscaleIPs || []
              };
            } else {
              root.exitNodeStatus = null;
            }
          } else {
            root.tailscaleIp = "";
            root.tailscaleStatus = root.tailscaleRunning ? "Connected" : "Disconnected";
            root.peerCount = 0;
            root.setPeerList([]);
            root.exitNodeStatus = null;
          }
        } catch (e) {
          Logger.e("Tailscale", "Failed to parse status: " + e);
          root.tailscaleRunning = false;
          root.needsLogin = false;
          root.tailscaleIp = "";
          root.tailscaleStatus = "Error";
          root.peerCount = 0;
          root.setPeerList([]);
          root.exitNodeStatus = null;
        }
      } else {
        root.tailscaleRunning = false;
        root.needsLogin = false;
        root.tailscaleStatus = "Disconnected";
        root.tailscaleIp = "";
        root.peerCount = 0;
        root.setPeerList([]);
        root.exitNodeStatus = null;
      }
    }
  }

  // ─── Taildrop send state ─────────────────────────────────────────────────

  // Possible values: "idle", "sending", "error"
  property string taildropState: "idle"
  property string taildropMessage: ""

  readonly property bool taildropEnabled: pluginApi?.pluginSettings?.taildropEnabled ?? pluginApi?.manifest?.metadata?.defaultSettings?.taildropEnabled ?? true

  Process {
    id: taildropSendProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onStarted: {
      root.taildropState = "sending";
      root.taildropMessage = "";
      Logger.i("Tailscale", "Taildrop send started");
    }

    onExited: function (exitCode, exitStatus) {
      var stderr = String(taildropSendProcess.stderr.text || "").trim();
      if (exitCode === 0) {
        root.taildropState = "idle";
        root.taildropMessage = "";
        ToastService.showNotice(pluginApi?.tr("toast.title"), pluginApi?.tr("taildrop.toast.sent"), "file-upload");
        Logger.i("Tailscale", "Taildrop send completed successfully");
      } else {
        root.taildropState = "error";
        root.taildropMessage = stderr || pluginApi?.tr("taildrop.error.unknown");
        ToastService.showError(pluginApi?.tr("toast.title"), root.taildropMessage, "file-x");
        Logger.e("Tailscale", "Taildrop send failed (exit " + exitCode + "): " + root.taildropMessage);
      }
    }
  }

  // files: array of local file paths, peerTarget: "hostname:" or "ip:"
  function sendFilesViaTaildrop(files, peerTarget) {
    if (!root.tailscaleInstalled || !root.tailscaleRunning) {
      Logger.w("Tailscale", "Cannot send: tailscale not running");
      return;
    }
    if (!root.taildropEnabled) {
      Logger.w("Tailscale", "Taildrop is disabled in settings");
      return;
    }
    if (!files || files.length === 0) {
      Logger.w("Tailscale", "No files to send");
      return;
    }
    if (root.taildropState === "sending") {
      Logger.w("Tailscale", "Already sending files");
      return;
    }
    var cmd = ["tailscale", "file", "cp"];
    for (var i = 0; i < files.length; i++) {
      cmd.push(files[i]);
    }
    cmd.push(peerTarget);
    taildropSendProcess.command = cmd;
    taildropSendProcess.running = true;
  }

  function checkTailscaleInstalled() {
    root.isRefreshing = true;
    whichProcess.command = ["which", "tailscale"];
    whichProcess.running = true;
  }

  function updateTailscaleStatus() {
    if (!root.tailscaleInstalled) {
      root.tailscaleRunning = false;
      root.needsLogin = false;
      root.tailscaleIp = "";
      root.tailscaleStatus = "Not installed";
      root.peerCount = 0;
      root.setPeerList([]);
      root.exitNodeStatus = null;
      return;
    }

    root.isRefreshing = true;
    statusProcess.command = ["tailscale", "status", "--json"];
    statusProcess.running = true;
  }

  Timer {
    id: updateTimer
    interval: refreshInterval
    repeat: true
    running: true
    triggeredOnStart: true

    onTriggered: {
      if (root.tailscaleInstalled === false) {
        checkTailscaleInstalled();
      } else {
        updateTailscaleStatus();
      }
    }
  }

  Component.onCompleted: {
    checkTailscaleInstalled();
  }

  IpcHandler {
    target: "plugin:tailscale"

    function togglePanel() {
      pluginApi.withCurrentScreen(screen => {
                                    pluginApi.togglePanel(screen);
                                  });
    }

    function status() {
      return {
        "installed": root.tailscaleInstalled,
        "running": root.tailscaleRunning,
        "ip": root.tailscaleIp,
        "status": root.tailscaleStatus,
        "peers": root.peerCount,
        "needsLogin": root.needsLogin
      };
    }

    function refresh() {
      updateTailscaleStatus();
    }

  }
}
