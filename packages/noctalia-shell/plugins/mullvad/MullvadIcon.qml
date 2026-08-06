import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root

  property real pointSize: Style.fontSizeL
  property bool applyUiScale: true
  property bool crossed: false
  property color color: Color.mOnSurface

  readonly property real iconSize: Math.max(1, applyUiScale ? pointSize * Style.uiScaleRatio : pointSize)

  implicitWidth: iconSize
  implicitHeight: iconSize

  Image {
    anchors.fill: parent
    source: "mullvad.svg"
    sourceSize.width: root.iconSize
    sourceSize.height: root.iconSize
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true

    layer.enabled: true
    layer.effect: ShaderEffect {
      property color targetColor: root.color
      property real colorizeMode: 2.0
      fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
    }
  }

  Item {
    anchors.fill: parent
    visible: root.crossed
    rotation: -45

    Rectangle {
      anchors.centerIn: parent
      width: root.iconSize * 1.18
      height: Math.max(3, root.iconSize * 0.2)
      radius: height / 2
      color: Color.mSurface
    }

    Rectangle {
      anchors.centerIn: parent
      width: root.iconSize * 1.08
      height: Math.max(1, root.iconSize * 0.08)
      radius: height / 2
      color: root.color
    }
  }
}
