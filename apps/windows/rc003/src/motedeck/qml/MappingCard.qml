import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

// 设计稿 .kc：300×56，36px 键帽 + 三个手势格（small 标签 + 24px 值块）。
AbstractButton {
    id: root

    property var tokens
    property string cardId: ""
    property string buttonName: ""
    property real keyLabelWidth: 36
    property string singleText: ""
    property string doubleText: ""
    property string longText: ""
    property string singleNoteText: ""
    property string doubleNoteText: ""
    property string longNoteText: ""
    property bool selected: false
    property bool voiceAction: false
    property bool exposeObjectNames: true
    // 放在右侧面板里当手势选择器时打开：点某个格就切到那个手势。
    property bool selectableGestures: false
    property string activeGesture: "single_click"
    signal gesturePicked(string gesture)

    hoverEnabled: true
    implicitWidth: 300
    implicitHeight: 56
    leftPadding: 8
    rightPadding: 8
    topPadding: 0
    bottomPadding: 0
    objectName: exposeObjectNames ? "editMapping_" + cardId : ""
    Accessible.name: buttonName + qsTr("按键映射")

    function displayBinding(text) {
        const shortcuts = {
            "Escape": "Esc",
            "Return": "Enter",
            "回车": "Enter",
            "Delete": "Del",
            "Delete（退格）": "Del",
            "退格": "Del",
            "方向上": "↑",
            "方向下": "↓",
            "方向左": "←",
            "方向右": "→",
            "系统音量 +": "Vol +",
            "系统音量 −": "Vol -"
        }
        if (shortcuts[text])
            return shortcuts[text]
        return text ? text.replace(/\s*\+\s*/g, " + ") : ""
    }

    // 只有纯 ASCII 键码用等宽字体，中文和箭头用界面字体。
    function isKeyCode(text) {
        return /^[A-Za-z0-9 +\-]+$/.test(text)
    }

    component ValueBlock: Item {
        id: block
        property string text: ""
        property bool empty: false
        property bool mono: false
        property bool active: false
        property string labelObjectName: ""
        property alias label: valueLabel

        Layout.fillWidth: true
        Layout.preferredHeight: 24
        implicitHeight: 24

        Rectangle {
            anchors.fill: parent
            visible: !block.empty
            radius: 7
            color: block.active
                ? root.tokens.accentSoft
                : root.selected ? root.tokens.surface : root.tokens.surfaceMuted
            border.width: block.active || root.selected
                ? root.tokens.hairlineWidth : 0
            border.color: block.active ? root.tokens.accent : root.tokens.accentLine
        }

        Shape {
            anchors.fill: parent
            visible: block.empty
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.tokens.borderStrong
                strokeWidth: root.tokens.hairlineWidth
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 2]
                fillColor: "transparent"
                PathRectangle {
                    x: 0.5
                    y: 0.5
                    width: block.width - 1
                    height: block.height - 1
                    radius: 6.5
                }
            }
        }

        UiLabel {
            id: valueLabel
            objectName: block.labelObjectName
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            tokens: root.tokens
            kind: bodyKind
            text: block.text
            color: block.empty ? root.tokens.textTertiary : root.tokens.textPrimary
            font.family: block.mono ? root.tokens.fontFamilyMono : root.tokens.fontFamily
            font.pixelSize: root.tokens.fontSizeMappingKey
            font.weight: block.empty ? Font.Normal : Font.Medium
            lineHeight: 1.0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component GestureCell: ColumnLayout {
        id: cell
        property string gestureId: ""
        property string gestureLabel: ""
        property string bindingText: ""
        property string noteText: ""
        property string valueObjectName: ""
        readonly property bool active:
            root.selectableGestures && root.activeGesture === cell.gestureId
        readonly property bool empty:
            !bindingText || bindingText.trim().length === 0
            || bindingText.trim() === qsTr("未设置")
        readonly property bool usingNote:
            !empty && noteText && noteText.trim().length > 0
            && noteText.trim() !== qsTr("未命名")
        readonly property string shownText: empty
            ? qsTr("未设置")
            : usingNote
                ? noteText.trim() : root.displayBinding(bindingText.trim())

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignVCenter
        spacing: 2
        // 面板里没选中的手势格淡一些；鼠标拂过时提亮，引导点击切换。
        opacity: !root.selectableGestures || cell.active
            ? 1.0 : (cellHover.hovered ? 0.85 : 0.45)
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // 面板里当手势开关用：点这个格就是把动作写给这个手势。
        TapHandler {
            enabled: root.selectableGestures
            onTapped: root.gesturePicked(cell.gestureId)
        }
        HoverHandler {
            id: cellHover
            enabled: root.selectableGestures
            cursorShape: Qt.PointingHandCursor
        }

        UiLabel {
            id: gestureTitle
            tokens: root.tokens
            kind: noteKind
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            text: cell.gestureLabel
            color: cell.active ? root.tokens.accent : root.tokens.textTertiary
            font.pixelSize: root.tokens.fontSizeSmall
            font.weight: Font.Normal
            lineHeight: 1.0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            HoverHandler { id: gestureHover }
            CompactToolTip {
                tokens: root.tokens
                active: gestureHover.hovered && !cell.empty
                    && (cell.usingNote || valueBlock.label.truncated)
                text: cell.usingNote
                    ? cell.noteText.trim() + " · " + cell.bindingText.trim()
                    : cell.bindingText.trim()
            }
        }

        ValueBlock {
            id: valueBlock
            text: cell.shownText
            empty: cell.empty
            mono: !cell.empty && !cell.usingNote && root.isKeyCode(cell.shownText)
            active: cell.active
            labelObjectName: cell.valueObjectName
        }
    }

    component VoicePausedCell: ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        Layout.columnSpan: 2
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        UiLabel {
            tokens: root.tokens
            kind: noteKind
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            text: qsTr("双击 / 长按")
            color: root.tokens.textTertiary
            font.pixelSize: root.tokens.fontSizeSmall
            lineHeight: 1.0
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        ValueBlock {
            text: qsTr("语音模式下暂停")
            empty: false
            labelObjectName: root.exposeObjectNames
                ? "mappingVoicePausedText_" + root.cardId : ""
        }
    }

    background: Rectangle {
        radius: root.tokens.cornerRadiusCard
        color: root.selected ? root.tokens.accentSoft : root.tokens.surface
        border.width: root.tokens.hairlineWidth
        border.color: root.selected
            ? root.tokens.accent
            : root.hovered
                ? root.tokens.borderStrong : root.tokens.cardBorder

        // 选中外圈：0 0 0 4px halo
        Rectangle {
            visible: root.selected
            anchors.fill: parent
            anchors.margins: -4
            z: -1
            radius: parent.radius + 4
            color: "transparent"
            border.width: 4
            border.color: root.tokens.halo
        }
    }

    contentItem: GridLayout {
        columns: 4
        columnSpacing: 6
        rowSpacing: 0

        // 键帽 .k：36×36，圆角 10，底边 2px
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            Layout.alignment: Qt.AlignVCenter
            radius: 10
            color: root.selected ? root.tokens.accent : root.tokens.borderStrong
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: 2
                radius: 10
                color: root.selected ? root.tokens.accent : root.tokens.surfaceMuted
                border.width: root.tokens.hairlineWidth
                border.color: root.selected ? root.tokens.accent : root.tokens.line
            }

            MappingKeyLabel {
                objectName: root.exposeObjectNames ? "mappingKeyCell_" + root.cardId : ""
                tokens: root.tokens
                anchors.fill: parent
                anchors.bottomMargin: 2
                text: root.buttonName
                color: root.selected ? root.tokens.accentText : root.tokens.textPrimary
                Accessible.name: text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        GestureCell {
            objectName: root.exposeObjectNames ? "mappingSingleCell_" + root.cardId : ""
            gestureId: "single_click"
            gestureLabel: qsTr("单击")
            bindingText: root.singleText
            noteText: root.singleNoteText
            valueObjectName: root.exposeObjectNames
                ? "mappingSinglePrimaryText_" + root.cardId : ""
        }

        GestureCell {
            objectName: root.exposeObjectNames ? "mappingDoubleCell_" + root.cardId : ""
            visible: !root.voiceAction
            gestureId: "double_click"
            gestureLabel: qsTr("双击")
            bindingText: root.doubleText
            noteText: root.doubleNoteText
            valueObjectName: root.exposeObjectNames
                ? "mappingDoublePrimaryText_" + root.cardId : ""
        }

        GestureCell {
            objectName: root.exposeObjectNames ? "mappingLongCell_" + root.cardId : ""
            visible: !root.voiceAction
            gestureId: "long_press"
            gestureLabel: qsTr("长按")
            bindingText: root.longText
            noteText: root.longNoteText
            valueObjectName: root.exposeObjectNames
                ? "mappingLongPrimaryText_" + root.cardId : ""
        }

        VoicePausedCell {
            objectName: root.exposeObjectNames
                ? "mappingVoicePausedCell_" + root.cardId : ""
            visible: root.voiceAction
        }
    }
}
