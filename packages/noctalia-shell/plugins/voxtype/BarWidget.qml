import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var voxtypeState: pluginApi?.mainInstance?.voxtypeState || null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property string state: voxtypeState?.value ?? "unavailable"
  readonly property bool available: state !== "unavailable"
  readonly property string icon: "microphone"
  readonly property string tooltip: state === "recording" ? "Voxtype: Recording" : state === "transcribing" ? "Voxtype: Transcribing" : "Voxtype: Ready"
  readonly property color color: state === "recording" ? Color.mError : state === "transcribing" ? Color.mTertiary : Color.mOnSurfaceVariant

  implicitWidth: available ? pill.width : 0
  implicitHeight: available ? pill.height : 0
  visible: available

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.icon
    tooltipText: root.tooltip
    forceClose: true
    customTextIconColor: root.color
  }
}
