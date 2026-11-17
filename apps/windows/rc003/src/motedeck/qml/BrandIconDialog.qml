import QtQuick
import QtQuick.Controls
import MoteDeckSettings 1.0

// 点击窗口左上角图标弹出的图标风格选择：
// 1. MoteDeck 经典：0.2.0 版本的老胶囊图标
// 2. Milo 经典：当前默认图标
// 点击任意一项立即保存生效并关闭窗口。
SettingsDialog {
    id: root
    objectName: "brandIconDialog"
    title: qsTr("选择图标")
    closeButtonObjectName: "closeBrandIconDialogButton"
    preferredWidth: 420

    component IconOption: AbstractButton {
        id: option
        property int mode: 0
        property string label: ""
        property string note: ""
        property string previewSource: ""
        readonly property bool selected: SettingsController.brandIconMode === option.mode
        width: parent.width
        implicitHeight: 56
        hoverEnabled: true
        Accessible.name: label + "，" + note

        contentItem: Item {
            Image {
                id: preview
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                source: option.previewSource
                sourceSize.width: 32 * Screen.devicePixelRatio
                sourceSize.height: 32 * Screen.devicePixelRatio
                mipmap: true
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            Column {
                anchors.left: preview.right
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                UiLabel {
                    tokens: root.tokens
                    kind: bodyKind
                    text: option.label
                    color: root.tokens.textPrimary
                }
                UiLabel {
                    tokens: root.tokens
                    kind: noteKind
                    text: option.note
                    color: root.tokens.textSecondary
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: 8
                color: option.selected ? root.tokens.accent : "transparent"
                border.width: 1
                border.color: option.selected ? root.tokens.accent : root.tokens.border

                IconGlyph {
                    tokens: root.tokens
                    anchors.centerIn: parent
                    glyph: "\uE73E"
                    glyphSize: 10
                    color: root.tokens.accentText
                    visible: option.selected
                }
            }
        }

        background: Rectangle {
            radius: root.tokens.cornerRadiusControl
            color: option.hovered ? root.tokens.hover : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
        }

        onClicked: {
            SettingsController.setBrandIconMode(option.mode)
            root.close()
        }
    }

    contentItem: Column {
        spacing: root.tokens.spacingSmall

        IconOption {
            mode: 1
            label: qsTr("MoteDeck 经典")
            note: qsTr("0.2.0 版本图标")
            previewSource: root.tokens.darkMode
                ? "assets/brand-mark-classic-dark.svg" : "assets/brand-mark-classic.svg"
        }

        IconOption {
            mode: 0
            label: qsTr("Milo 经典")
            note: qsTr("默认图标")
            previewSource: root.tokens.darkMode
                ? "assets/brand-mark-dark.svg" : "assets/brand-mark.svg"
        }
    }
}
