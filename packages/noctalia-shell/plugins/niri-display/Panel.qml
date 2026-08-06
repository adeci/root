import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import "DisplayState.js" as DisplayState

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property var displayService: pluginApi?.mainInstance?.displayService || null
  // Source and target are output.selection_key values, never connector-only identity.
  property string source: ""
  property string target: ""
  property bool selectionsInitialized: false

  readonly property var outputs: displayService?.outputs || []
  readonly property var allModel: displayService?.outputModel(false) || []
  readonly property var activeModel: displayService?.outputModel(true) || []
  readonly property var sourceOutput: DisplayState.outputForKey(outputs, source)
  readonly property var targetOutput: DisplayState.outputForKey(outputs, target)
  readonly property bool targetExists: targetOutput !== null
  readonly property bool targetActive: targetOutput?.active === true
  readonly property bool validActivePair: DisplayState.validActivePair(outputs, source, target)
  readonly property bool validExtendPair: DisplayState.validExtendPair(outputs, source, target)
  readonly property bool mirrorActive: displayService?.mirror?.active === true
  readonly property bool actionRunning: displayService?.actionRunning === true
  readonly property string mirrorSource: root.mirrorActive ? (displayService.mirror.source || "") : ""
  readonly property string mirrorTarget: root.mirrorActive ? (displayService.mirror.target || "") : ""

  // SmartPanel reads these names from the plugin slot.
  readonly property real contentPreferredWidth: Math.round(420 * Style.uiScaleRatio)
  readonly property real contentPreferredHeight: Math.round(680 * Style.uiScaleRatio)

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"
  }

  function outputLabel(name) {
    for (var i = 0; i < outputs.length; i++) {
      var output = outputs[i];
      if (output.name === name)
        return output.friendly ? output.friendly + " (" + output.name + ")" : output.name;
    }
    return name;
  }

  function outputSummary(output) {
    var state = output.focused ? "Focused" : output.active ? "Active" : "Off";
    if (!output.active)
      return output.name + " - " + state;
    if (!output.current_mode)
      return output.name + " - " + state + " - scale " + output.logical.scale;
    return output.name + " - " + state + " - " + output.current_mode.width + "x"
        + output.current_mode.height + " @ " + output.current_mode.refresh_hz + " Hz";
  }

  function initializeSelections() {
    var state = DisplayState.reconcileSelections(outputs, source, target, selectionsInitialized);
    source = state.source;
    target = state.target;
    selectionsInitialized = state.initialized;
  }

  function applyMirror() {
    var arguments = DisplayState.mirrorArguments(outputs, source, target);
    if (arguments !== null)
      displayService?.act(arguments);
  }

  function applyExtend() {
    var arguments = DisplayState.extendArguments(outputs, source, target);
    if (arguments !== null)
      displayService?.act(arguments);
  }

  function applyPlace(direction) {
    var arguments = DisplayState.placeArguments(outputs, source, target, direction);
    if (arguments !== null)
      displayService?.act(arguments);
  }

  onOutputsChanged: initializeSelections()
  Component.onCompleted: initializeSelections()

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginL

    RowLayout {
      Layout.fillWidth: true

      NIcon {
        icon: "device-desktop"
        pointSize: Style.fontSizeXL
        color: Color.mPrimary
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        NText {
          text: "Displays"
          font.pixelSize: Style.fontSizeL
          font.bold: true
          color: Color.mOnSurface
        }
        NText {
          text: "Mirror or arrange connected displays"
          font.pixelSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }
      NIconButton {
        icon: "refresh"
        baseSize: 32
        tooltipText: "Refresh connected displays"
        onClicked: displayService?.refresh()
      }
    }

    NScrollView {
      id: detailsScroll
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      horizontalPolicy: ScrollBar.AlwaysOff
      verticalPolicy: ScrollBar.AsNeeded
      reserveScrollbarSpace: false
      showGradientMasks: false
      gradientColor: Color.mSurface

      ColumnLayout {
        id: detailsContent
        x: Style.marginS
        width: Math.max(0, detailsScroll.availableWidth - Style.margin2S)
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          NText {
            text: root.outputs.length === 1 ? "Connected display" : "Connected displays"
            font.bold: true
            color: Color.mOnSurface
            Layout.fillWidth: true
          }
          NText {
            text: root.mirrorActive ? "Mirroring" : ""
            font.pixelSize: Style.fontSizeS
            color: Color.mTertiary
          }
        }

        Repeater {
          model: root.outputs

          delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: outputRow.implicitHeight + Style.margin2M
            radius: Style.radiusM
            color: Color.mSurfaceVariant
            border.width: modelData.focused ? Style.borderS : 0
            border.color: Color.mPrimary

            RowLayout {
              id: outputRow
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginM

              NIcon {
                icon: modelData.active ? "device-desktop" : "device-desktop-off"
                color: modelData.focused ? Color.mPrimary : Color.mOnSurfaceVariant
              }
              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                NText {
                  Layout.fillWidth: true
                  text: modelData.friendly
                  font.bold: modelData.focused
                  color: Color.mOnSurface
                  elide: Text.ElideRight
                }
                NText {
                  Layout.fillWidth: true
                  text: root.outputSummary(modelData)
                  color: Color.mOnSurfaceVariant
                  font.pixelSize: Style.fontSizeS
                  elide: Text.ElideRight
                }
              }
            }
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: sourcePicker.implicitHeight + Style.margin2M
          radius: Style.radiusM
          color: Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: Color.mPrimary

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: "screen-share"
              pointSize: Style.fontSizeXL
              color: Color.mPrimary
            }
            NComboBox {
              id: sourcePicker
              Layout.fillWidth: true
              label: "Source display"
              model: root.activeModel
              currentKey: root.source
              placeholder: "Select source"
              tooltip: "The focused active display is selected by default."
              onSelected: key => root.source = key
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: targetPicker.implicitHeight + Style.margin2M
          radius: Style.radiusM
          color: Color.mSurfaceVariant
          border.width: Style.borderS
          border.color: Color.mTertiary

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: "device-desktop"
              pointSize: Style.fontSizeXL
              color: Color.mTertiary
            }
            NComboBox {
              id: targetPicker
              Layout.fillWidth: true
              label: "Target display"
              model: root.allModel
              currentKey: root.target
              placeholder: "Select target"
              tooltip: root.targetActive ? "Ready to mirror, extend, or arrange."
                                           : "Extend turns on this display; mirroring and placement require an active target."
              onSelected: key => root.target = key
            }
          }
        }

        NDivider {
          Layout.fillWidth: true
        }

        NText {
          text: "Arrange displays"
          font.bold: true
          color: Color.mOnSurface
        }
        NText {
          text: "Place the target relative to the source."
          font.pixelSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }

        GridLayout {
          Layout.fillWidth: true
          columns: 3
          columnSpacing: Style.marginS
          rowSpacing: Style.marginS

          NButton {
            Layout.row: 0
            Layout.column: 1
            Layout.fillWidth: true
            text: "Above"
            icon: "arrow-up"
            tooltipText: "Place the target above the source."
            enabled: root.validActivePair && !root.actionRunning
            onClicked: root.applyPlace("above")
          }
          NButton {
            Layout.row: 1
            Layout.column: 0
            Layout.fillWidth: true
            text: "Left"
            icon: "arrow-left"
            tooltipText: "Place the target to the left of the source."
            enabled: root.validActivePair && !root.actionRunning
            onClicked: root.applyPlace("left-of")
          }
          Rectangle {
            Layout.row: 1
            Layout.column: 1
            Layout.fillWidth: true
            implicitHeight: Style.baseWidgetSize
            radius: Style.iRadiusS
            color: Color.mSurfaceVariant
            border.width: Style.borderS
            border.color: Color.mOutline

            NText {
              anchors.centerIn: parent
              text: "Source"
              font.pixelSize: Style.fontSizeS
              font.bold: true
              color: Color.mOnSurfaceVariant
            }
          }
          NButton {
            Layout.row: 1
            Layout.column: 2
            Layout.fillWidth: true
            text: "Right"
            icon: "arrow-right"
            tooltipText: "Place the target to the right of the source."
            enabled: root.validActivePair && !root.actionRunning
            onClicked: root.applyPlace("right-of")
          }
          NButton {
            Layout.row: 2
            Layout.column: 1
            Layout.fillWidth: true
            text: "Below"
            icon: "arrow-down"
            tooltipText: "Place the target below the source."
            enabled: root.validActivePair && !root.actionRunning
            onClicked: root.applyPlace("below")
          }
        }

        NText {
          text: "Mode and scale changes made with niri-display last until restart."
          color: Color.mOnSurfaceVariant
          font.pixelSize: Style.fontSizeS
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }

    NDivider {
      Layout.fillWidth: true
    }

    NText {
      text: "Display mode"
      font.bold: true
      color: Color.mOnSurface
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        Layout.fillWidth: true
        text: "Mirror"
        icon: "screen-share"
        tooltipText: "Show the source on the active target display."
        enabled: root.validActivePair && !root.actionRunning
        onClicked: root.applyMirror()
      }
      NButton {
        Layout.fillWidth: true
        text: "Extend"
        icon: "device-desktop"
        backgroundColor: Color.mSecondary
        textColor: Color.mOnSecondary
        tooltipText: "Turn on the target as its own display."
        enabled: root.validExtendPair && !root.actionRunning
        onClicked: root.applyExtend()
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: root.mirrorActive
      implicitHeight: activeMirrorRow.implicitHeight + Style.margin2M
      radius: Style.radiusS
      color: Color.mSurfaceVariant
      border.width: Style.borderS
      border.color: Color.mTertiary

      RowLayout {
        id: activeMirrorRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NIcon {
          icon: "screen-share"
          color: Color.mTertiary
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0

          NText {
            text: "Active mirror"
            font.pixelSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
          NText {
            Layout.fillWidth: true
            text: root.outputLabel(root.mirrorSource) + " -> " + root.outputLabel(root.mirrorTarget)
            font.bold: true
            color: Color.mOnSurface
            elide: Text.ElideRight
          }
        }
        NButton {
          text: "Stop mirroring"
          icon: "square"
          outlined: true
          backgroundColor: Color.mError
          textColor: Color.mError
          tooltipText: "Stop the mirror started by niri-display."
          enabled: !root.actionRunning
          onClicked: displayService?.act(["mirror-stop"])
        }
      }
    }
  }
}
