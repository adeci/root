import QtQuick
import Quickshell.Io
import "DisplayState.js" as DisplayState

Item {
  id: root

  property var pluginApi: null
  property alias displayService: displayService

  QtObject {
    id: displayService

    property var outputs: []
    property var mirror: null
    property string fetchState: "idle"
    property string refreshError: ""
    property string actionError: ""
    property string actionMessage: ""
    property bool actionRunning: actionProcess.running

    function outputModel(activeOnly) {
      return DisplayState.outputModel(outputs, activeOnly);
    }

    function refresh() {
      if (queryProcess.running)
        return;
      fetchState = "loading";
      queryProcess.command = ["niri-display", "outputs", "--json"];
      queryProcess.running = true;
    }

    function act(arguments) {
      if (actionProcess.running) {
        actionError = "A display action is already running. Wait for it to finish.";
        return;
      }
      actionError = "";
      actionMessage = "";
      actionProcess.command = ["niri-display"].concat(arguments);
      actionProcess.running = true;
    }
  }

  Process {
    id: queryProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        displayService.fetchState = "error";
        displayService.refreshError = stderr.text.trim() || ("niri-display exited " + exitCode);
        return;
      }
      try {
        var value = JSON.parse(stdout.text);
        if (value.version !== 1 || !Array.isArray(value.outputs)
            || value.outputs.some(output => typeof output.selection_key !== "string"))
          throw new Error("unsupported niri-display JSON document");
        displayService.outputs = value.outputs;
        displayService.mirror = value.mirror || null;
        displayService.fetchState = "success";
        displayService.refreshError = "";
      } catch (error) {
        displayService.fetchState = "error";
        displayService.refreshError = "Invalid response from niri-display: " + error;
      }
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      if (exitCode === 0) {
        displayService.actionMessage = stdout.text.trim();
        displayService.actionError = "";
      } else {
        displayService.actionMessage = "";
        displayService.actionError = stderr.text.trim() || ("niri-display exited " + exitCode);
      }
      displayService.refresh();
    }
  }

  Timer {
    interval: 15000
    repeat: true
    running: pluginApi !== null
    triggeredOnStart: true
    onTriggered: displayService.refresh()
  }
}
