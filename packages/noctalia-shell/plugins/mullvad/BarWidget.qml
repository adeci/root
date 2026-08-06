import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

Item {
	id: root

	property var pluginApi: null
	property ShellScreen screen
	property string widgetId: ""
	property string section: ""
	property int sectionWidgetIndex: -1
	property int sectionWidgetsCount: 0

	readonly property string screenName: screen ? screen.name : ""
	readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
	readonly property bool isVertical: barPosition === "left" || barPosition === "right"

	readonly property var main: pluginApi?.mainInstance
	readonly property string vpnState: main?.state ?? "disconnected"
	readonly property bool locked: main?.locked ?? false
	readonly property bool installed: main?.installed ?? false

	readonly property color stateColor: {
		if (!installed) return Color.mError
		if (locked || vpnState === "error") return Color.mError
		if (vpnState === "connecting" || vpnState === "disconnecting") return Color.mTertiary
		return Color.mOnSurface
	}

	property real margins: Style.marginM * 2

	readonly property real contentWidth: isVertical ? Style.capsuleHeight : Math.round(layout.implicitWidth + margins)
	readonly property real contentHeight: isVertical ? Math.round(layout.implicitHeight + margins) : Style.capsuleHeight

	implicitWidth: installed ? contentWidth : 0
	implicitHeight: installed ? contentHeight : 0
	visible: installed

	Layout.alignment: Qt.AlignVCenter

	Rectangle {
		id: visualCapsule
		x: Style.pixelAlignCenter(parent.width, width)
		y: Style.pixelAlignCenter(parent.height, height)
		width: root.contentWidth
		height: root.contentHeight
		radius: Style.radiusM
		color: Style.capsuleColor
		border.color: Style.capsuleBorderColor
		border.width: Style.capsuleBorderWidth

		Item {
			id: layout
			anchors.verticalCenter: parent.verticalCenter
			anchors.horizontalCenter: parent.horizontalCenter
			implicitWidth: iconRow.implicitWidth
			implicitHeight: iconRow.implicitHeight

			RowLayout {
				id: iconRow
				spacing: Style.marginXS

				MullvadIcon {
					pointSize: Style.fontSizeXL
					applyUiScale: false
					crossed: root.vpnState === "disconnected" || root.vpnState === "error"
					color: root.stateColor
				}

				NText {
					visible: !root.isVertical && !(root.main?.compactMode ?? true) && (root.main?.showCityName ?? false) && root.vpnState === "connected"
					text: root.main?.currentLocation?.city || ""
					pointSize: Style.fontSizeXS
					color: Color.mOnSurface
				}

				NText {
					visible: !root.isVertical && !(root.main?.compactMode ?? true) && (root.main?.showIp ?? false) && root.vpnState === "connected" && (root.main?.currentLocation?.ipv4 || "").length > 0
					text: root.main?.currentLocation?.ipv4 || ""
					pointSize: Style.fontSizeXS
					font.family: Settings.data.ui.fontFixed
					color: Color.mOnSurface
				}
			}
		}
	}

	NPopupContextMenu {
		id: contextMenu
		model: [
			{
				"label": pluginApi?.tr(root.vpnState === "connected" ? "context.disconnect" : "context.connect"),
				"action": "toggle",
				"icon": root.vpnState === "connected" ? "shield-off" : "shield",
				"enabled": root.installed
			},
			{
				"label": pluginApi?.tr("context.open-panel"),
				"action": "panel",
				"icon": "menu"
			},
			{
				"label": pluginApi?.tr("actions.widget-settings"),
				"action": "widget-settings",
				"icon": "settings"
			}
		]
		onTriggered: action => {
			contextMenu.close()
			PanelService.closeContextMenu(screen)
			if (action === "toggle") root.main?.toggleVpn()
			else if (action === "panel") pluginApi?.openPanel(screen, root)
			else if (action === "widget-settings") BarService.openPluginSettings(screen, pluginApi.manifest)
		}
	}

	function _tooltipText() {
		if (!root.installed) return pluginApi?.tr("state.not-installed")
		if (root.vpnState === "error") return pluginApi?.tr("state.error")
		if (root.vpnState === "connected" && root.main?.currentLocation) {
			var loc = root.main.currentLocation
			return pluginApi?.tr("state.connected") + ": " +
				(loc.city || loc.country) +
				(loc.hostname ? "\n" + loc.hostname : "") +
				(loc.ipv4 ? "\n" + loc.ipv4 : "")
		}
		if (root.locked) return pluginApi?.tr("state.blocked")
		return pluginApi?.tr("state.disconnected")
	}

	MouseArea {
		id: mouseArea
		anchors.fill: parent
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		acceptedButtons: Qt.LeftButton | Qt.RightButton

		onEntered: TooltipService.show(root, root._tooltipText(), BarService.getTooltipDirection(root.screen?.name))
		onExited: TooltipService.hide()

		onClicked: (mouse) => {
			if (mouse.button === Qt.LeftButton) {
				if ((root.main?.clickAction || "toggle") === "toggle") {
					root.main?.toggleVpn()
				} else {
					pluginApi?.openPanel(root.screen, root)
				}
			} else if (mouse.button === Qt.RightButton) {
				PanelService.showContextMenu(contextMenu, root, screen)
			}
		}
	}
}
