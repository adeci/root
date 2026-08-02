import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var displayService: pluginApi?.mainInstance?.displayService || null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property int activeCount: {
    var count = 0;
    var outputs = displayService?.outputs || [];
    for (var i = 0; i < outputs.length; i++)
      if (outputs[i].active)
        count++;
    return count;
  }
  readonly property string errorMessage: displayService?.actionError || displayService?.refreshError || ""
  readonly property bool failed: errorMessage !== ""
  readonly property bool mirroring: displayService?.mirror?.active === true

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill
    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: root.failed ? "alert-triangle" : root.mirroring ? "screen-share" : "device-desktop"
    text: root.activeCount.toString()
    tooltipText: root.failed ? root.errorMessage : root.mirroring ? "Mirroring displays" : "Display controls"
    forceOpen: root.mirroring || root.failed
    autoHide: true
    customTextIconColor: root.failed ? Color.mError : root.mirroring ? Color.mTertiary : Color.mOnSurfaceVariant

    onClicked: pluginApi?.openPanel(root.screen, root)
  }
}
