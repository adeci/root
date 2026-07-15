import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var pluginApi: null
  property alias voxtypeState: state

  QtObject {
    id: state
    property string value: "unavailable"
  }

  FileView {
    id: stateFile
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "") + "/voxtype/state"
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: state.value = text().trim() || "idle"
    onLoadFailed: state.value = "unavailable"
  }
}
