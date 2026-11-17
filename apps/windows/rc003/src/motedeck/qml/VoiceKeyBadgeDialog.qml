// 语音键徽章窗口：定义方框里的单字/图标和字色；托盘指示当前语音模式
// 用的就是同一份徽章，切换气泡的字色也跟随这里选的颜色。
// SettingsController is a QML singleton - see main.qml.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MoteDeckSettings 1.0

SettingsDialog {
    id: root
    objectName: "voiceKeyBadgeDialog"
    title: qsTr("语音键徽章")
    titleNote: qsTr("方框里的单字用于托盘指示当前语音模式。")
    preferredWidth: 440
    closeButtonObjectName: "voiceKeyBadgeCloseButton"
    standardButtons: Dialog.Ok | Dialog.Cancel

    property int slot: 0
    // 打开时后端算好的默认显示（命名取首字 / 未命名取序号）。
    property string autoDisplay: ""
    // 本地暂存的选择：点「确定」才写入配置。
    property string pendingText: ""
    property string pendingGlyph: ""
    property string pendingColor: ""
    // 底色：空=跟随系统深浅模式，dark=黑底（默认字自动变白），light=白底。
    property string pendingBg: ""

    // 预置图标：Segoe Fluent/MDL2 的常用字形，托盘渲染用同一套字体。
    readonly property var glyphOptions: [
        { "code": "E720", "name": qsTr("麦克风") },
        { "code": "E765", "name": qsTr("键盘") },
        { "code": "E767", "name": qsTr("音量") },
        { "code": "E8BD", "name": qsTr("消息") },
        { "code": "E787", "name": qsTr("日历") },
        { "code": "E713", "name": qsTr("设置") }
    ]
    // 预置字色；空字符串表示跟随主题（只换字色，方框底色不变）。
    readonly property var colorOptions: [
        { "value": "", "name": qsTr("默认") },
        { "value": "#0078D4", "name": qsTr("蓝") },
        { "value": "#C42B1C", "name": qsTr("红") },
        { "value": "#0F7B0F", "name": qsTr("绿") },
        { "value": "#CA5010", "name": qsTr("橙") },
        { "value": "#8764B8", "name": qsTr("紫") },
        { "value": "#038387", "name": qsTr("青") },
        { "value": "#E3008C", "name": qsTr("品红") }
    ]
    // 预置底色；空字符串表示跟随系统深浅模式自动切换。
    readonly property var bgOptions: [
        { "value": "", "name": qsTr("跟系统") },
        { "value": "dark", "name": qsTr("黑底") },
        { "value": "light", "name": qsTr("白底") }
    ]

    // 预览方框与托盘 PNG 同一套配色：底色用所选深浅（未选则跟系统），
    // 字色用所选颜色；黑底时默认黑字自动变白字。
    readonly property bool previewDark:
        root.pendingBg === "dark"
        || (root.pendingBg.length === 0 && root.tokens.darkMode)
    readonly property color previewBackground:
        root.previewDark ? "#18181b" : "#ffffff"
    readonly property color previewBorder:
        root.previewDark ? "#7a7a80" : "#d6d6db"
    readonly property color previewText:
        root.pendingColor.length > 0
            ? root.pendingColor
            : (root.previewDark ? "#ffffff" : "#121214")
    readonly property string previewDisplay:
        root.pendingGlyph.length > 0
            ? String.fromCharCode(parseInt(root.pendingGlyph, 16))
            : (root.pendingText.length > 0
                ? root.pendingText : root.autoDisplay)
    readonly property string iconFontFamily:
        Qt.fontFamilies().indexOf("Segoe Fluent Icons") >= 0
            ? "Segoe Fluent Icons"
            : Qt.fontFamilies().indexOf("Segoe MDL2 Assets") >= 0
                ? "Segoe MDL2 Assets" : root.tokens.fontFamily

    // 「跟系统」色块：深浅渐变示意两种主题都会跟随。
    Gradient {
        id: bgSystemGradient
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#18181b" }
        GradientStop { position: 1.0; color: "#ffffff" }
    }

    function openForSlot(slotId) {
        root.slot = Number(slotId)
        root.pendingText = ""
        root.pendingGlyph = ""
        root.pendingColor = ""
        root.pendingBg = ""
        root.autoDisplay = ""
        const rows = SettingsController.voiceKeyConfigs
        for (var i = 0; i < rows.length; i++) {
            if (Number(rows[i].id) !== root.slot)
                continue
            const row = rows[i]
            root.pendingText = String(row.badgeText || "")
            root.pendingGlyph = String(row.badgeGlyph || "")
            root.pendingColor = String(row.badgeColor || "")
            root.pendingBg = String(row.badgeBg || "")
            // 自动显示规则与后端一致：命名取首字，未命名取列表序号。
            if (row.badgeAuto) {
                root.autoDisplay = String(row.badgeDisplay || "")
            } else {
                const name = String(row.name || "").trim()
                root.autoDisplay = name.length > 0
                    ? name.charAt(0) : String(i + 1)
            }
            break
        }
        root.open()
    }

    onAccepted: {
        SettingsController.setVoiceKeyConfigBadge(
            root.slot, root.pendingText, root.pendingGlyph,
            root.pendingColor, root.pendingBg)
    }

    // 左侧标签列统一宽度，四行的控件从同一条竖线开始，避免参差不齐。
    readonly property real labelColumnWidth: 36

    contentItem: ColumnLayout {
        spacing: root.tokens.spacingLarge

        // 预览条：整条浅底圆角，左边是托盘实际观感，右边一句说明。
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 72
            radius: 10
            color: root.tokens.surfaceMuted

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: root.tokens.spacingMedium

                Rectangle {
                    id: badgePreview
                    objectName: "voiceKeyBadgePreview"
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: 12
                    color: root.previewBackground
                    border.width: 2
                    border.color: root.previewBorder

                    Label {
                        anchors.centerIn: parent
                        visible: root.previewDisplay.length > 0
                        text: root.previewDisplay
                        font.family: root.pendingGlyph.length > 0
                            ? root.iconFontFamily : root.tokens.fontFamily
                        font.pixelSize: root.pendingGlyph.length > 0 ? 24 : 22
                        font.bold: root.pendingGlyph.length === 0
                        renderType: Text.QtRendering
                        color: root.previewText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                UiLabel {
                    Layout.fillWidth: true
                    tokens: root.tokens
                    kind: noteKind
                    wrapMode: Text.WordWrap
                    text: root.autoDisplay.length > 0
                        ? qsTr("留空单字按默认显示“%1”。").arg(root.autoDisplay)
                        : qsTr("留空单字按默认规则显示。")
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: root.tokens.spacingMedium
            rowSpacing: root.tokens.spacingMedium

            // 单字：最多一个字符；输入后清掉图标选择。
            UiLabel {
                tokens: root.tokens
                kind: noteKind
                Layout.preferredWidth: root.labelColumnWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                text: qsTr("单字")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.tokens.spacingSmall

                CompactTextField {
                    id: badgeTextField
                    objectName: "voiceKeyBadgeTextField"
                    tokens: root.tokens
                    Layout.preferredWidth: 96
                    maximumLength: 1
                    placeholderText: root.autoDisplay.length > 0
                        ? root.autoDisplay : qsTr("1")
                    text: root.pendingText
                    Accessible.name: qsTr("单字")
                    onTextEdited: {
                        root.pendingText = text
                        if (text.length > 0)
                            root.pendingGlyph = ""
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // 图标：选中后清掉单字；再点一次取消回到单字。
            UiLabel {
                tokens: root.tokens
                kind: noteKind
                Layout.preferredWidth: root.labelColumnWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                text: qsTr("图标")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.tokens.spacingSmall

                Repeater {
                    model: root.glyphOptions

                    delegate: AbstractButton {
                        id: glyphOption
                        required property var modelData
                        readonly property bool selected:
                            root.pendingGlyph === String(modelData.code)
                        objectName: "voiceKeyBadgeGlyph_" + String(modelData.code)
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        hoverEnabled: true
                        Accessible.name: String(modelData.name)
                        onClicked: {
                            if (selected) {
                                root.pendingGlyph = ""
                                return
                            }
                            root.pendingGlyph = String(modelData.code)
                            root.pendingText = ""
                            badgeTextField.text = ""
                        }
                        contentItem: Rectangle {
                            radius: 8
                            color: glyphOption.selected
                                ? root.tokens.accentSoft
                                : glyphOption.hovered
                                    ? root.tokens.buttonHover
                                    : root.tokens.surface
                            border.width: 1
                            border.color: glyphOption.selected
                                ? root.tokens.accent : root.tokens.border

                            IconGlyph {
                                anchors.centerIn: parent
                                tokens: root.tokens
                                glyph: String.fromCharCode(
                                    parseInt(glyphOption.modelData.code, 16))
                                glyphSize: 16
                                color: glyphOption.selected
                                    ? root.tokens.accent
                                    : root.tokens.textSecondary
                            }
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // 颜色：只换字色，方框底色仍按深浅模式。
            UiLabel {
                tokens: root.tokens
                kind: noteKind
                Layout.preferredWidth: root.labelColumnWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                text: qsTr("颜色")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.tokens.spacingSmall

                Repeater {
                    model: root.colorOptions

                    delegate: AbstractButton {
                        id: colorOption
                        required property var modelData
                        readonly property bool selected:
                            root.pendingColor === String(modelData.value)
                        objectName: "voiceKeyBadgeColor_"
                            + (String(modelData.value).length > 0
                                ? String(modelData.value) : "default")
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        hoverEnabled: true
                        Accessible.name: String(modelData.name)
                        onClicked: root.pendingColor = String(modelData.value)
                        contentItem: Rectangle {
                            radius: 14
                            color: String(colorOption.modelData.value).length > 0
                                ? String(colorOption.modelData.value)
                                : "transparent"
                            border.width: colorOption.selected ? 2 : 1
                            border.color: colorOption.selected
                                ? root.tokens.accent : root.tokens.border

                            IconGlyph {
                                anchors.centerIn: parent
                                visible: colorOption.selected
                                tokens: root.tokens
                                glyph: "\uE73E"
                                glyphSize: 12
                                color: colorOption.modelData.value.length > 0
                                    ? "#ffffff" : root.tokens.accent
                            }
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            // 底色：强制方框深浅；「跟系统」随 Windows 深浅模式自动切换。
            // 切黑底时默认黑字自动变白字，所选彩字不变。
            UiLabel {
                tokens: root.tokens
                kind: noteKind
                Layout.preferredWidth: root.labelColumnWidth
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                text: qsTr("底色")
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.tokens.spacingSmall

                Repeater {
                    model: root.bgOptions

                    delegate: AbstractButton {
                        id: bgOption
                        required property var modelData
                        readonly property bool isSystem:
                            String(modelData.value).length === 0
                        readonly property bool selected:
                            root.pendingBg === String(modelData.value)
                        objectName: "voiceKeyBadgeBg_"
                            + (isSystem ? "system" : String(modelData.value))
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        hoverEnabled: true
                        Accessible.name: String(modelData.name)
                        onClicked: root.pendingBg = String(modelData.value)
                        contentItem: Rectangle {
                            radius: 8
                            color: bgOption.isSystem ? "transparent" : (
                                String(bgOption.modelData.value) === "dark"
                                    ? "#18181b" : "#ffffff")
                            gradient: bgOption.isSystem ? bgSystemGradient : null
                            border.width: bgOption.selected ? 2 : 1
                            border.color: bgOption.selected
                                ? root.tokens.accent : root.tokens.border

                            IconGlyph {
                                anchors.centerIn: parent
                                visible: bgOption.selected
                                tokens: root.tokens
                                glyph: "\uE73E"
                                glyphSize: 12
                                color: bgOption.isSystem
                                    ? root.tokens.accent
                                    : (String(bgOption.modelData.value) === "dark"
                                        ? "#ffffff" : "#121214")
                            }
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
