import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Shapes
import MoteDeckSettings 1.0

Item {
    id: root
    property var tokens
    property var backTabTarget: null
    property var tabTarget: null
    readonly property var firstFocusItem: openBluetoothSettingsButton
    readonly property var lastFocusItem: closeBehaviorSwitch
    readonly property int deviceStateColumnWidth: 96
    readonly property int deviceActionColumnWidth: tokens.buttonWidth4Chars
    signal openButtonsRequested()

    function restoreLogExportFocus() {
        Qt.callLater(function() {
            if (root.Window.window)
                root.Window.window.requestActivate()
            if (deviceOpenLogButton.enabled)
                deviceOpenLogButton.forceActiveFocus()
            else
                diagnosticTraceSwitch.forceActiveFocus()
        })
    }

    FileDialog {
        id: logExportDialog
        objectName: "logExportDialog"
        title: qsTr("导出日志")
        fileMode: FileDialog.SaveFile
        nameFilters: [qsTr("ZIP 压缩文件 (*.zip)")]
        defaultSuffix: "zip"
        onAccepted: {
            SettingsController.exportLogs(selectedFile)
            root.restoreLogExportFocus()
        }
        onRejected: root.restoreLogExportFocus()
    }

    function checkResult(checkId) {
        const rows = DiagnosticsController.checkResults
        for (var i = 0; i < rows.length; i++) {
            if (String(rows[i].checkId) === checkId)
                return rows[i]
        }
        return null
    }

    // 红/黄都是需要用户接手才能恢复的状态：此时横幅右上角给出「求助 AI」
    // 入口。绿（已连接）、灰（未检查/等待就绪）和未选设备都不算卡住；
    // 「未连接」只是遥控器关机/断开了，等它回来接上即可，同样不算卡住。
    readonly property bool deviceStateStuck: {
        const code = currentDeviceStateCode()
        return code !== "paired" && code !== "unchecked"
            && code !== "pending" && code !== "unselected"
            && code !== "disconnected"
    }

    // 万能求助提示词：项目仓库、当前状态快照、日志分流口诀、提权专项和
    // 分层排查清单，一次性交给 AI，让它能按步骤接手排查。
    function aiHelpPromptText() {
        return [
            qsTr("你好，请帮我排查 MoteDeck（小米或谷歌蓝牙遥控器的 Windows 客户端）无法正常接收遥控器按键的问题。"),
            qsTr("项目仓库在 GitHub：https://github.com/HZDavy/MoteDeck（PySide6/QML 桌面应用，rc003 客户端核心逻辑在 apps/windows/rc003/src/motedeck 目录，含后台服务 bridge 和按键注入模块）。本机是安装版、没有源码；如果日志指向代码问题，请给出结论和日志证据（时间+关键行），我来转给开发者，不要让我改代码。"),
            qsTr("应用版本：" + SettingsController.applicationVersion + "；当前设备：" + SettingsController.activeRemoteLabel + "（型号由软件按蓝牙广播名/GATT 型号串实际读取，分不清时由我手选，可能与实物不符）。"),
            qsTr("当前状态快照：界面显示=" + currentDeviceStateText()
                + "；服务进程运行=" + SettingsController.bridgeRunning
                + "；服务已连接遥控器=" + SettingsController.bridgeConnected
                + "；按键注入通道=" + SettingsController.hidTapState
                + "；标准输入通道=" + SettingsController.rawInputState + "。"),
            qsTr("日志文件在 %LOCALAPPDATA%\\MoteDeck\\logs\\（app.log、hid-helper.log），请先读日志再下结论。"),
            qsTr("排查规则：按键要过几道关才能到达目标应用。每一步先告诉我要做什么，一步一步来，不要一次性丢一堆命令。"),
            qsTr("第 0 步（永远先做）：在两个日志文件里搜 PhysicalKeyInUseError、injection_attempt_id、hid_copy_health、connect_gatt、waiting_neutral、cleanup_pending、ERROR、Traceback，以及“服务无法在此时接受控制信息”，告诉我命中哪些，再按下面分类排查。"),
            qsTr("【专项】仅当界面显示「待启动服务」/「未完成管理员授权」，或启动服务、以管理员身份运行报“服务无法在此时接受控制信息”时才进入（否则跳过）。这是提权通道问题，按顺序走："),
            qsTr("1. 查注册表：reg query \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\"，看 EnableLUA、ConsentPromptBehaviorAdmin、FilterAdministratorToken 三个值（EnableLUA=0x1、ConsentPromptBehaviorAdmin=0x5 是正常；FilterAdministratorToken=1 是已知元凶之一）。"),
            qsTr("2. 让我重启电脑试一次（Appinfo 审批服务卡死，重启即活）。"),
            qsTr("3. 重启后无效、管理员命令行还报“服务无法在此时接受控制信息”→ 走恢复环境：开始菜单按住 Shift 点重启 → 疑难解答 → 高级选项 → 命令提示符（恢复环境权限全开）。先 dir C:\\Windows / dir D:\\Windows 确认系统盘符（恢复环境里盘符可能变），再 reg load HKLM\\TEMP <系统盘>\\Windows\\System32\\config\\SOFTWARE 离线加载，把 FilterAdministratorToken 改回 0；顺带 reg load HKLM\\SYSTMP <系统盘>\\Windows\\System32\\config\\SYSTEM 查 Services\\Appinfo 的 Start（0x4 是被禁用，改回 3），改完 reg unload HKLM\\TEMP 和 reg unload HKLM\\SYSTMP 卸载，退出重启。"),
            qsTr("4. 回到系统后跑 sfc /scannow 修系统文件（蓝牙栈异常也可能被它顺带修好）。"),
            qsTr("5. 检查杀毒软件是否拦截了 helper 程序启动（查杀软隔离/拦截记录，把安装目录加白名单）。"),
            qsTr("【主分类】服务正常运行但按键没反应时，按此排查："),
            qsTr("一、遥控器和蓝牙链路（收不到事件）：遥控器没电/深度休眠→换电池或按键唤醒再试；配对记录损坏或被删→删除配对重连；蓝牙适配器省电/驱动异常→设备管理器关闭“允许计算机关闭此设备以节约电源”；Bluetooth Support Service 未运行→启动并设为自动；日志反复出现 connect_gatt ConnectionError→跑 sfc /scannow；距离远/2.4G 干扰→靠近主机、远离 USB3.0 设备再试。"),
            qsTr("二、MoteDeck 应用层（收到了但没处理）：日志里 hid_copy_health 心跳的 injection_attempt_id 长时间不变 + 反复 PhysicalKeyInUseError = 拦截会话挂死（已知软件 bug，表现为时好时坏、过阵子自己恢复）→ 重启 MoteDeck 绕过，不要折腾系统设置；日志出现 cleanup_pending 长期不释放 = 语音键状态锁死（已上报）→ 重启 MoteDeck 绕过；部分按键行为不对（某些键没反应/功能错乱）且设备名可能与实物不符 = 型号判错导致映射不对 → 用设备页的型号确认功能改对型号；界面“未选择设备”或选择报错 → 设备页重新“选择设备”。"),
            qsTr("三、注入到达目标应用（注入了但应用没收到）：目标应用以管理员身份运行会吞掉低权限注入 → 改为普通权限；目标应用在后台没焦点 → 点一下目标应用窗口再按；快捷键被截图工具/输入法/其他全局热键抢占 → 换一个快捷键试试；游戏独占全屏 → 改为无边框窗口。"),
            qsTr("四、语音链路特有（按键活了但没有声音）：声音设置里找不到 CABLE Output → 重装虚拟声卡驱动；目标应用的麦克风要选 CABLE Output 不是物理麦克风；设置→隐私→麦克风，允许桌面应用访问。"),
            qsTr("五、系统环境（特殊情况）：锁屏/UAC 安全桌面弹出时注入被拦截属正常现象，回桌面再试；远程桌面/快速用户切换下注入可能无效 → 在物理会话里试。"),
            qsTr("输出要求：最后给结论——命中哪几条（可多选，软件 bug 靠重启绕过、系统问题优先修）、每条的日志证据（时间+关键行）、我接下来要执行的操作、需要开发者修复的具体问题。")
        ].join("\n")
    }

    function currentDeviceStateCode() {
        if (!SettingsController.activeRemoteKey)
            return "unselected"
        if (!SettingsController.activeRemoteReady)
            return "pending"
        if (!SettingsController.bridgeRunning && !SettingsController.bridgeLaunchBusy)
            return "service_stopped"
        if (!SettingsController.isRc003Device) {
            // 谷歌遥控器：管理员授权没完成（UAC 被取消或失败）时按键收不
            // 进来，跟小米一样退回「待启动服务」，不能显示成「已连接」。
            if (SettingsController.bridgeRunning
                    && SettingsController.rawInputState
                        === "chromecast_permission_cancelled")
                return "service_stopped"
            if (SettingsController.bridgeConnected)
                return "paired"
            // 服务在跑却没连上：以实连为准，别拿扫描快照里的配对记录
            // 冒充「已连接」，否则连接中/重连时会来回闪。
            if (SettingsController.bridgeRunning)
                return "disconnected"
            return SettingsController.activeRemotePairingState
        }
        // 服务已经连上遥控器时以实连为准：启动时那次探测失败，不能把已连上
        // 的链路显示成「点击“重新检查”」。但管理员授权停在未完成/已取消时
        // 按键收不进来，不能显示成「已连接」，退回「待启动服务」。
        if (sourceAuthorizationRetryAvailable())
            return "service_stopped"
        if (SettingsController.bridgeConnected)
            return "paired"
        if (DiagnosticsController.isRefreshing)
            return "checking"
        const row = checkResult("ble_candidate")
        if (!row)
            return "unchecked"
        const resultCode = String(row.resultCode || "")
        if (resultCode === "selected_missing")
            return "selected_missing"
        if (resultCode === "ambiguous")
            return "conflict"
        if (resultCode === "no_candidate")
            return "unpaired"
        if (row.status === "pass") {
            // 探测结果只是上一次扫描留下的快照，遥控器关机/拔电池后不会
            // 自动失效。服务在跑、而实连（bridgeConnected）没建立，就说明
            // 此刻确实没连上——直接按断开显示，不要拿旧快照冒充「已连接」，
            // 否则启动时会在「连接中 / 等待重连」之间不停闪烁。
            return "disconnected"
        }
        if (row.status === "manual")
            return "waiting"
        return "error"
    }

    function currentDeviceStateText() {
        switch (currentDeviceStateCode()) {
        case "unselected": return qsTr("请选择设备")
        case "pending": return qsTr("接收尚未接入")
        case "selected_missing": return qsTr("所选设备未连接")
        case "checking": return qsTr("正在检查")
        case "paired": return qsTr("已连接")
        case "disconnected": return qsTr("未连接")
        case "waiting": return qsTr("正在确认")
        case "service_stopped": return qsTr("待启动服务")
        case "receiver_failed": return qsTr("接收失败")
        case "conflict": return qsTr("设备识别异常")
        case "unpaired": return qsTr("点击“蓝牙设置”")
        case "error": return qsTr("点击“重新检查”")
        default: return qsTr("未检查")
        }
    }

    function currentDeviceDetailText() {
        return SettingsController.activeRemoteLabel
    }

    function currentDeviceStateColor() {
        const code = currentDeviceStateCode()
        if (code === "paired")
            return tokens.successColor
        if (code === "checking" || code === "waiting")
            return tokens.voiceAccent
        if (code === "service_stopped")
            return tokens.darkMode ? "#facc15" : "#ca8a04"
        if (code === "unchecked" || code === "pending")
            return tokens.disabledText
        return tokens.errorColor
    }

    function valueIn(value, choices) {
        return choices.indexOf(String(value)) >= 0
    }

    function rawInputReady() {
        return SettingsController.rawInputState === "ready"
    }

    function hidTapReady() {
        return valueIn(SettingsController.hidTapState, [
            "attached_waiting_for_hid_io", "ready"
        ])
    }

    function rawInputWaitsForRemote() {
        return valueIn(SettingsController.rawInputState, [
            "no_device", "device_removed"
        ])
    }

    function hidTapWaitsForRemote() {
        return valueIn(SettingsController.hidTapState, [
            "waiting_for_rc003_host", "waiting_for_gadget_connection"
        ])
    }

    function buttonReceiverWaitsForRemote() {
        return hidTapWaitsForRemote()
            && (rawInputWaitsForRemote() || rawInputReady())
    }

    function rawInputChecking() {
        return valueIn(SettingsController.rawInputState, [
            "unknown", "starting", "recovering"
        ])
    }

    function hidTapChecking() {
        return valueIn(SettingsController.hidTapState, [
            "unknown", "verified_not_started", "starting", "injecting", "recovering"
        ])
    }

    function voiceKeyChecking() {
        return valueIn(SettingsController.voiceKeyPhysicalizerState, [
            "unknown", "starting", "recovering"
        ])
    }

    function voiceKeyFailed() {
        return valueIn(SettingsController.voiceKeyPhysicalizerState, [
            "failed", "stopped"
        ])
    }

    function buttonReceiverStateCode() {
        if (!SettingsController.activeRemoteKey)
            return "unselected"
        if (!SettingsController.activeRemoteReady)
            return "pending"
        if (SettingsController.bridgeRunning) {
            if (SettingsController.hidTapState === "authorization_cancelled")
                return "source_authorization_cancelled"
            if (SettingsController.hidTapState === "authorization_failed")
                return "source_authorization_failed"
            if (SettingsController.hidTapState === "unavailable_gadget_not_verified")
                return "component_unavailable"
            if (SettingsController.hidTapState === "selected_device_shared_host")
                return "shared_host"
            if (SettingsController.hidTapState === "restart_required")
                return "restart_computer"
            if (SettingsController.bridgeLaunchBusy
                    || SettingsController.bridgeReconnectBusy)
                return "checking"
            if (SettingsController.rawInputState === "ambiguous")
                return "conflict"
            const rawReady = rawInputReady()
            const tapReady = hidTapReady()
            const deviceCode = currentDeviceStateCode()
            if (SettingsController.buttonReceiverUsable)
                return "ready"
            if (rawReady && tapReady) {
                if (voiceKeyFailed())
                    return "voice_error"
                if (voiceKeyChecking())
                    return "checking"
                return "checking"
            }
            if (buttonReceiverWaitsForRemote()) {
                if (deviceCode === "unpaired")
                    return "unpaired"
                if (deviceCode === "conflict")
                    return "conflict"
                return "waiting_remote"
            }
            if (rawReady)
                return hidTapChecking() || hidTapWaitsForRemote()
                    ? "checking" : "original_only"
            if (tapReady)
                return rawInputWaitsForRemote() ? "recovering"
                    : rawInputChecking() ? "checking" : "custom_only"
            if (rawInputChecking() || hidTapChecking())
                return "checking"
            return "error"
        }
        if (DiagnosticsController.isRefreshing)
            return "checking"
        const osRow = checkResult("os_version")
        if (osRow && (osRow.status === "fail" || osRow.status === "unsupported"))
            return "system_error"
        const rawRow = checkResult("raw_input")
        if (!rawRow)
            return "unchecked"
        const rawCode = String(rawRow.resultCode || "")
        if (rawCode === "ambiguous")
            return "conflict"
        if (rawCode === "no_device") {
            const deviceCode = currentDeviceStateCode()
            if (deviceCode === "unpaired")
                return "unpaired"
            if (deviceCode === "conflict")
                return "conflict"
            return "waiting_remote"
        }
        if (rawRow.status === "pass")
            return "service_stopped"
        return "error"
    }

    function buttonReceiverStateText() {
        switch (buttonReceiverStateCode()) {
        case "unselected": return qsTr("请先选择设备")
        case "pending": return qsTr("接收尚未接入")
        case "source_authorization_cancelled": return qsTr("授权已取消")
        case "source_authorization_failed": return qsTr("授权未完成")
        case "checking": return qsTr("正在检查")
        case "recovering": return qsTr("正在恢复")
        case "component_unavailable": return qsTr("按键组件不完整")
        case "restart_computer": return qsTr("请重启电脑一次")
        case "shared_host": return qsTr("按键来源待区分")
        case "waiting_remote": return qsTr("未连接")
        case "unpaired": return qsTr("请先配对遥控器")
        case "conflict": return qsTr("设备识别异常")
        case "ready": return qsTr("正常")
        case "service_stopped": return qsTr("待启动服务")
        case "custom_only": return qsTr("点击“重启服务”")
        case "original_only": return qsTr("点击“重启服务”")
        case "voice_error": return qsTr("点击“重启服务”")
        case "system_error": return qsTr("请升级系统")
        case "error": return SettingsController.bridgeRunning
            ? qsTr("点击“重启服务”") : qsTr("点击“重新检查”")
        default: return qsTr("未检查")
        }
    }

    function buttonReceiverStateColor() {
        const code = buttonReceiverStateCode()
        if (code === "ready")
            return tokens.successColor
        if (code === "checking" || code === "waiting_remote" || code === "recovering"
                || code === "custom_only"
                || code === "original_only")
            return tokens.voiceAccent
        if (code === "unchecked" || code === "pending"
                || code === "service_stopped")
            return tokens.disabledText
        return tokens.errorColor
    }

    function bridgeStateText() {
        if (sourceAuthorizationRetryAvailable())
            return qsTr("等待按键授权")
        if (SettingsController.activeRemoteKey && !SettingsController.activeRemoteReady)
            return qsTr("接收尚未接入")
        if (SettingsController.bridgeReconnectBusy)
            return qsTr("连接中")
        if (SettingsController.bridgeLaunchPhase === "stopping")
            return qsTr("正在停止")
        if (SettingsController.bridgeLaunchBusy)
            return qsTr("启动中")
        if (!SettingsController.bridgeRunning)
            return qsTr("待启动服务")
        if (bridgeNeedsRestartAction())
            return qsTr("点击“重启服务”")
        const receiverCode = buttonReceiverStateCode()
        if (SettingsController.bridgeConnected)
            return qsTr("已连接")
        if (SettingsController.bridgeRunning) {
            const connectionCode = String(SettingsController.bridgeConnectionState)
            if (connectionCode === "retry_wait")
                return qsTr("点击“重新连接”")
            if (connectionCode === "connecting")
                return qsTr("正在连接遥控器")
            if (receiverCode === "waiting_remote")
                return qsTr("正在等待连接")
            if (receiverCode === "unpaired" || receiverCode === "conflict")
                return qsTr("请先处理设备")
            if (bridgeReconnectActionAvailable())
                return qsTr("点击“重新连接”")
            return qsTr("正在等待连接")
        }
        if (SettingsController.bridgeLaunchPhase === "unknown"
                || SettingsController.bridgeLaunchPhase === "failed")
            return qsTr("启动失败")
        return qsTr("点击“启动服务”")
    }

    function bridgeReconnectActionAvailable() {
        if (!SettingsController.bridgeReconnectAvailable)
            return false
        const code = currentDeviceStateCode()
        if (code === "unpaired" || code === "conflict" || code === "error")
            return false
        const connectionCode = String(SettingsController.bridgeConnectionState)
        if (connectionCode === "retry_wait")
            return true
        if (connectionCode !== "waiting_for_device")
            return false
        return SettingsController.buttonReceiverUsable
    }

    function bridgeNeedsRestartAction() {
        if (sourceAuthorizationRetryAvailable())
            return false
        if (!SettingsController.bridgeRunning)
            return false
        if (SettingsController.hidTapState === "restart_required")
            return false
        if (SettingsController.isRc003Device
                && SettingsController.hidTapState === "unavailable_gadget_not_verified")
            return false
        if (SettingsController.bridgeRestartRecommended)
            return true
        const code = buttonReceiverStateCode()
        return code === "custom_only" || code === "original_only"
            || code === "voice_error" || code === "error"
    }

    function bridgeActionVisible() {
        if (sourceAuthorizationRetryAvailable())
            return true
        if (!SettingsController.bridgeRunning)
            return true
        if (SettingsController.bridgeLaunchPhase === "stopping")
            return false
        if (SettingsController.bridgeLaunchBusy
                || SettingsController.bridgeReconnectBusy)
            return true
        if (bridgeNeedsRestartAction())
            return true
        if (SettingsController.bridgeConnected)
            return false
        return bridgeReconnectActionAvailable()
    }

    function bridgeActionText() {
        if (SettingsController.bridgeReconnectBusy)
            return qsTr("连接中…")
        if (SettingsController.bridgeLaunchBusy)
            return qsTr("启动中…")
        if (!SettingsController.bridgeRunning)
            return qsTr("启动服务")
        if (sourceAuthorizationRetryAvailable())
            return qsTr("重新授权")
        if (bridgeNeedsRestartAction())
            return qsTr("重启服务")
        return qsTr("重新连接")
    }

    function bridgeStateColor() {
        if (!SettingsController.bridgeRunning)
            return tokens.darkMode ? "#facc15" : "#ca8a04"
        if (sourceAuthorizationRetryAvailable())
            return tokens.errorColor
        if (bridgeNeedsRestartAction())
            return tokens.errorColor
        if (SettingsController.bridgeConnectionState === "retry_wait")
            return tokens.errorColor
        if (SettingsController.bridgeConnected)
            return tokens.successColor
        const receiverCode = buttonReceiverStateCode()
        if (receiverCode === "unpaired" || receiverCode === "conflict")
            return tokens.errorColor
        if (SettingsController.bridgeLaunchPhase === "unknown"
                || SettingsController.bridgeLaunchPhase === "failed")
            return tokens.errorColor
        if (SettingsController.bridgeReconnectBusy
                || SettingsController.bridgeRunning
                || SettingsController.bridgeLaunchBusy
                || !SettingsController.bridgeRunning)
            return tokens.voiceAccent
        return tokens.disabledText
    }

    function sourceAuthorizationRetryAvailable() {
        return SettingsController.isRc003Device && SettingsController.bridgeRunning
            && valueIn(SettingsController.hidTapState, ["authorization_cancelled", "authorization_failed"])
    }

    RemoteDeviceDialog {
        id: remoteDeviceDialog
        tokens: root.tokens
        anchors.centerIn: parent
    }

    AboutDialog {
        id: aboutDialog
        tokens: root.tokens
    }

    SettingsDialog {
        id: stopBridgeConfirmDialog
        objectName: "stopBridgeConfirmDialog"
        tokens: root.tokens
        preferredWidth: 390
        title: qsTr("关闭遥控器服务？")
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: SettingsController.stopBridge()

        contentItem: UiLabel {
            tokens: root.tokens
            kind: bodyKind
            wrapMode: Text.WordWrap
            text: qsTr("关闭后遥控器将无法接收按键和语音，可随时再打开。")
        }
    }

    // 「卡住了？求助AI」的二级弹窗：展示万能排查提示词，一键复制后
    // 用户直接粘给任意 AI 助手，让 AI 按提示词里的清单接手排查。
    SettingsDialog {
        id: aiHelpDialog
        objectName: "aiHelpDialog"
        tokens: root.tokens
        preferredWidth: 680
        title: qsTr("把这段话发给 AI")
        titleNote: qsTr("点“复制提示词”，粘贴给任意 AI 助手让它接手排查")

        property bool aiHelpCopied: false

        Timer {
            id: aiHelpCopiedTimer
            interval: 2000
            onTriggered: aiHelpDialog.aiHelpCopied = false
        }
        onClosed: aiHelpCopied = false

        contentItem: ColumnLayout {
            spacing: root.tokens.spacingMedium

            ScrollView {
                id: aiHelpPromptScroll
                objectName: "aiHelpPromptScroll"
                Layout.fillWidth: true
                Layout.preferredHeight: 300
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    objectName: "aiHelpPromptTextArea"
                    readOnly: true
                    text: root.aiHelpPromptText()
                    wrapMode: TextEdit.WordWrap
                    selectByMouse: true
                    color: root.tokens.textPrimary
                    font.family: root.tokens.fontFamily
                    font.pixelSize: root.tokens.fontSizeBody
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 10
                    bottomPadding: 10
                    background: Rectangle {
                        radius: root.tokens.cornerRadiusSmall
                        color: root.tokens.surfaceMuted
                        border.width: root.tokens.hairlineWidth
                        border.color: root.tokens.border
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.tokens.spacingMedium

                CompactButton {
                    id: copyAiHelpPromptButton
                    objectName: "copyAiHelpPromptButton"
                    tokens: root.tokens
                    text: aiHelpDialog.aiHelpCopied
                        ? qsTr("已复制") : qsTr("复制提示词")
                    Accessible.name: text
                    onClicked: {
                        SettingsController.copyTextToClipboard(
                            root.aiHelpPromptText())
                        aiHelpDialog.aiHelpCopied = true
                        aiHelpCopiedTimer.restart()
                    }
                }

                UiLabel {
                    tokens: root.tokens
                    kind: noteKind
                    Layout.fillWidth: true
                    text: qsTr("发给 AI 后，它会按提示词里的清单逐步帮你排查")
                }
            }
        }
    }

    // 小米两款遥控器分不清时的型号确认：蓝牙名相同、型号串没读到，
    // 让用户对着实物拍板；点设备卡右上角的问号也能随时打开这里改。
    SettingsDialog {
        id: remoteModelDialog
        objectName: "remoteModelDialog"
        tokens: root.tokens
        preferredWidth: 440
        title: qsTr("确认遥控器型号")
        titleNote: qsTr("对照实物遥控器选一个")
        standardButtons: Dialog.Ok | Dialog.Cancel

        property int pendingIndex: 0

        readonly property string savedProfile: {
            const key = SettingsController.remoteModelConfirmKey
            for (const row of SettingsController.remoteDeviceChoices) {
                if (row.key === key)
                    return row.profile
            }
            return ""
        }

        onAboutToShow: {
            pendingIndex = SettingsController.remoteModelOptions.findIndex(
                option => option.profile === savedProfile)
            if (pendingIndex < 0)
                pendingIndex = 0
        }
        onAccepted: {
            const options = SettingsController.remoteModelOptions
            if (pendingIndex >= 0 && pendingIndex < options.length)
                SettingsController.confirmRemoteModel(
                    SettingsController.remoteModelConfirmKey,
                    options[pendingIndex].profile)
        }

        contentItem: ColumnLayout {
            spacing: root.tokens.spacingMedium

            UiLabel {
                tokens: root.tokens
                kind: bodyKind
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("这台遥控器广播的蓝牙名和型号串都没能确认具体型号，请对照实物遥控器选一个。选错了可以随时点设备卡右上角的问号改回来。")
            }

            Repeater {
                model: SettingsController.remoteModelOptions

                delegate: AbstractButton {
                    id: modelOption
                    required property int index
                    required property var modelData
                    readonly property bool on: index === remoteModelDialog.pendingIndex
                    Layout.fillWidth: true
                    implicitHeight: 40
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: on
                    onClicked: remoteModelDialog.pendingIndex = index

                    background: Rectangle {
                        radius: root.tokens.cornerRadiusSmall
                        color: modelOption.on ? root.tokens.surfaceMuted : "transparent"
                        border.width: modelOption.on ? 1 : root.tokens.hairlineWidth
                        border.color: modelOption.on ? root.tokens.accent : root.tokens.border
                    }
                    contentItem: RowLayout {
                        spacing: root.tokens.spacingSmall

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            color: "transparent"
                            border.width: modelOption.on ? 5 : 1.5
                            border.color: modelOption.on
                                ? root.tokens.accent : root.tokens.border
                        }
                        UiLabel {
                            tokens: root.tokens
                            kind: bodyKind
                            Layout.fillWidth: true
                            text: modelOption.modelData.label
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: SettingsController
        function onRemoteModelConfirmRequested() {
            remoteModelDialog.open()
        }
    }

    QuickSetupDialog {
        id: quickSetupDialog
        tokens: root.tokens
    }

    ScrollView {
        id: deviceScroll
        objectName: "deviceScroll"
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        ColumnLayout {
            id: devicePageContent
            objectName: "devicePageContent"
            width: deviceScroll.availableWidth
            spacing: 0

            // ── 页面标题 ──
            Item {
                id: devicePageHeader
                objectName: "devicePageHeader"
                Layout.fillWidth: true
                Layout.preferredHeight: 60

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 40
                    spacing: 12

                    Label {
                        objectName: "devicePageTitle"
                        text: qsTr("设备")
                        font.family: tokens.fontFamilyDisplay
                        font.pixelSize: tokens.fontSizePageTitle
                        font.weight: Font.DemiBold
                        color: tokens.textPrimary
                        Layout.alignment: Qt.AlignBaseline
                    }
                    Label {
                        objectName: "devicePageSubtitle"
                        text: qsTr("遥控器、服务与启动行为")
                        font.family: tokens.fontFamily
                        font.pixelSize: tokens.fontSizeBody
                        color: tokens.textTertiary
                        Layout.alignment: Qt.AlignBaseline
                        Layout.fillWidth: true
                    }
                }
            }

            // ── 墨黑主卡：实物图 + 当前设备 + 右侧操作 ──
            Rectangle {
                id: deviceHero
                objectName: "currentDeviceRow"
                Layout.fillWidth: true
                Layout.preferredHeight: 132
                property string stateText: root.currentDeviceStateText()
                property string descriptionText: SettingsController.activeRemoteLabel
                property color stateColor: root.currentDeviceStateColor()
                radius: root.tokens.cornerRadiusCard
                clip: true
                color: "transparent"

                // linear-gradient(135deg, …)：Rectangle.gradient 只能横/竖，
                // 斜向底色用 Shape 的 LinearGradient 画。CSS 135° 的渐变线过中心、
                // 方向 (1,1)，长度 (W+H)/√2，起止点即中心 ∓ (W+H)/4。
                Shape {
                    id: heroBackdrop
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real reach: (width + height) / 4
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: heroBackdrop.width / 2 - heroBackdrop.reach
                            y1: heroBackdrop.height / 2 - heroBackdrop.reach
                            x2: heroBackdrop.width / 2 + heroBackdrop.reach
                            y2: heroBackdrop.height / 2 + heroBackdrop.reach
                            GradientStop {
                                position: 0.0
                                color: root.tokens && root.tokens.darkMode ? "#2a2a2a" : "#262626"
                            }
                            GradientStop {
                                position: 0.45
                                color: root.tokens && root.tokens.darkMode ? "#1c1c1c" : "#161616"
                            }
                            GradientStop {
                                position: 1.0
                                color: root.tokens && root.tokens.darkMode ? "#141414" : "#0c0c0c"
                            }
                        }
                        PathRectangle {
                            width: deviceHero.width
                            height: deviceHero.height
                            radius: deviceHero.radius
                        }
                    }
                }

                // 设计稿的两层径向柔光：
                //   radial-gradient(120% 140% at 12% 0%, rgba(255,255,255,.13), transparent 55%)
                //   radial-gradient(80% 120% at 100% 100%, rgba(255,255,255,.05), transparent 60%)
                // 用 HeroGlow 还原成真正的椭圆径向渐变，亮部从左上斜向衰减，
                // 不能再用整宽的竖向渐变（那会让卡片看起来是「上亮下暗」的直上直下）。
                HeroGlow {
                    hero: deviceHero
                    centerXFactor: 0.12
                    centerYFactor: 0.0
                    radiusXFactor: 1.2
                    radiusYFactor: 1.4
                    edgePosition: 0.55
                    glowColor: "#21ffffff"
                }

                HeroGlow {
                    hero: deviceHero
                    centerXFactor: 1.0
                    centerYFactor: 1.0
                    radiusXFactor: 0.8
                    radiusYFactor: 1.2
                    edgePosition: 0.6
                    glowColor: "#0dffffff"
                }

                // .hero-pic：112 宽，实物图高 280、top 14 只露上半截，
                // 从 60% 处开始透明渐隐（mask-image）；遥控器带投影，
                // 看上去像插在卡槽里，而不是压在卡片边缘上。
                Item {
                    id: heroPhoto
                    objectName: "deviceHeroPhoto"
                    x: 12
                    width: 112
                    height: parent.height
                    clip: true

                    Image {
                        id: heroPhotoImage
                        objectName: "deviceHeroPhotoImage"
                        y: 14
                        // 谷歌实物图是 453×1443 的细长机身，按 280 高放大会盖满卡槽；
                        // 只把谷歌档案放小，小米仍按设计稿的 280。
                        height: SettingsController.isRc003Device ? 280 : 230
                        width: sourceSize.height > 0
                            ? height * sourceSize.width / sourceSize.height : height * 2 / 3
                        x: (parent.width - width) / 2
                        source: SettingsController.photoAvailable
                            ? SettingsController.photoSource : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        layer.enabled: source.toString().length > 0
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#73000000"
                            shadowVerticalOffset: 10
                            shadowBlur: 0.9
                            blurMax: 18
                            autoPaddingEnabled: true
                        }
                    }

                    // 真正的 alpha 蒙版：linear-gradient(#000 60%, transparent)。
                    // 实物图到卡片底边时已完全透明，不会从圆角处露出，
                    // 也不会因斜向底色而出现一块颜色对不上的方块。
                    layer.enabled: heroPhotoImage.source.toString().length > 0
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: heroPhotoMask
                        // MultiEffect 掩码 = smoothstep(min·(1+s)−s, min·(1+s), α)；
                        // min 0.5、s 1 即 smoothstep(0, 1, α)，渐隐连续不截断。
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
                    }
                }

                Rectangle {
                    id: heroPhotoMask
                    objectName: "deviceHeroPhotoFade"
                    width: heroPhoto.width
                    height: heroPhoto.height
                    visible: false
                    layer.enabled: true
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffffff" }
                        GradientStop { position: 0.6; color: "#ffffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                }

                // .hero-body：两行（当前设备 + pill / 设备名），垂直居中
                Column {
                    anchors.left: heroPhoto.right
                    anchors.leftMargin: 20
                    anchors.right: heroActions.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Row {
                        spacing: 10
                        height: 22

                        Label {
                            text: qsTr("当前设备")
                            font.family: tokens.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#a3a3a3"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StatusPill {
                            tokens: root.tokens
                            onHero: true
                            ok: root.currentDeviceStateCode() === "paired"
                            label: root.currentDeviceStateText()
                            dotColor: ok ? "transparent" : root.currentDeviceStateColor()
                            visible: label.length > 0
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        objectName: "currentDeviceNameLabel"
                        width: parent.width
                        text: SettingsController.currentRemoteModelName.length > 0
                            ? SettingsController.currentRemoteModelName
                            : SettingsController.activeRemoteLabel
                        font.family: tokens.fontFamilyDisplay
                        font.pixelSize: tokens.fontSizeHeroTitle
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.24
                        lineHeight: 32
                        lineHeightMode: Text.FixedHeight
                        color: "#f2f2f2"
                        elide: Text.ElideRight
                    }
                }

                // .hero .act：贴底，margin-bottom 20，gap 4
                Row {
                    id: heroActions
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 20
                    spacing: 4

                    IconButton {
                        id: refreshDeviceChecksButton
                        objectName: "refreshDeviceChecksButton"
                        tokens: root.tokens
                        inverse: true
                        iconName: "refresh"
                        text: qsTr("重新检查")
                        enabled: !DiagnosticsController.isRefreshing
                            && !DiagnosticsController.vbCableTestRunning
                            && !SettingsController.configurationReadOnly
                        Accessible.name: DiagnosticsController.isRefreshing
                            ? qsTr("检查中…") : qsTr("重新检查")
                        onClicked: {
                            DiagnosticsController.refreshDiagnostics()
                            if (!SettingsController.isRc003Device)
                                SettingsController.refreshRemoteDevices()
                        }
                        KeyNavigation.backtab: root.backTabTarget
                        KeyNavigation.tab: openBluetoothSettingsButton
                    }

                    CompactButton {
                        id: openBluetoothSettingsButton
                        objectName: "openBluetoothSettingsButton"
                        tokens: root.tokens
                        inverse: true
                        flat: true
                        trailingIcon: "external"
                        text: qsTr("蓝牙设置")
                        Accessible.name: text
                        onClicked: SettingsController.openBluetoothSettings()
                        KeyNavigation.backtab: refreshDeviceChecksButton
                        KeyNavigation.tab: selectRemoteButton
                    }

                    CompactButton {
                        id: selectRemoteButton
                        objectName: "selectRemoteButton"
                        enabled: !SettingsController.configurationReadOnly
                        tokens: root.tokens
                        inverse: true
                        text: qsTr("选择设备")
                        onClicked: remoteDeviceDialog.open()
                        KeyNavigation.backtab: openBluetoothSettingsButton
                        KeyNavigation.tab: changeRemoteModelButton.visible
                            ? changeRemoteModelButton
                            : (root.deviceStateStuck
                                ? askAiHelpButton : buttonReceiverPrimaryButton)
                    }
                }

                // 右上角问号：随时手动改当前设备的型号。小米两款遥控器的
                // 蓝牙广播名相同、型号串也可能读不到，分不清时让用户自己拍板。
                IconButton {
                    id: changeRemoteModelButton
                    objectName: "changeRemoteModelButton"
                    tokens: root.tokens
                    inverse: true
                    iconName: "help"
                    visible: SettingsController.activeRemoteModelSelectable
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    Accessible.name: qsTr("确认遥控器型号")
                    Accessible.role: Accessible.Button
                    onClicked: remoteModelDialog.open()
                    KeyNavigation.backtab: selectRemoteButton
                    KeyNavigation.tab: root.deviceStateStuck
                        ? askAiHelpButton : buttonReceiverPrimaryButton
                }

                // 卡住时（红/黄状态）在横幅右上角给一个「求助 AI」入口：
                // 二级弹窗里是一段可直接复制给 AI 的万能排查提示词。
                CompactButton {
                    id: askAiHelpButton
                    objectName: "askAiHelpButton"
                    tokens: root.tokens
                    inverse: true
                    flat: true
                    text: qsTr("卡住了？求助AI")
                    Accessible.name: text
                    visible: root.deviceStateStuck
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    anchors.right: changeRemoteModelButton.visible
                        ? changeRemoteModelButton.left : parent.right
                    anchors.rightMargin: changeRemoteModelButton.visible ? 4 : 20
                    onClicked: aiHelpDialog.open()
                    KeyNavigation.backtab: changeRemoteModelButton.visible
                        ? changeRemoteModelButton : selectRemoteButton
                    KeyNavigation.tab: buttonReceiverPrimaryButton
                }

                // 1px 描边：放在最上层，避免被斜向底色 Shape 盖住；
                // 深色界面下靠它区分卡片和页面背景。
                Rectangle {
                    objectName: "deviceHeroBorder"
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: "#14ffffff"
                }
            }

            // ── 三块功能瓦片 ──
            RowLayout {
                id: deviceTiles
                objectName: "deviceTiles"
                Layout.fillWidth: true
                Layout.preferredHeight: 119
                Layout.topMargin: 16
                spacing: 12

                DeviceTile {
                    objectName: "buttonReceiverRow"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    tokens: root.tokens
                    iconName: "keys"
                    titleText: qsTr("按键接收")
                    descriptionText: root.buttonReceiverStateCode() === "source_authorization_cancelled"
                        ? qsTr("未完成管理员授权，点击“重新授权”")
                        : root.buttonReceiverStateCode() === "source_authorization_failed"
                        ? qsTr("未取得按键权限，点击“重新授权”")
                        : root.buttonReceiverStateCode() === "restart_computer"
                        ? qsTr("旧按键组件未释放，请重启电脑")
                        : root.buttonReceiverStateCode() === "component_unavailable"
                        ? qsTr("组件缺失或校验失败")
                        : root.buttonReceiverStateCode() === "recovering"
                        ? qsTr("按键设备尚未就绪，正在自动重试")
                        : qsTr("让遥控器按键在电脑上生效")
                    stateText: root.buttonReceiverStateText()
                    stateColor: root.buttonReceiverStateColor()

                    CompactButton {
                        id: buttonReceiverPrimaryButton
                        objectName: "openButtonSettingsButton"
                        tokens: root.tokens
                        flat: true
                        text: qsTr("快速配置")
                        onClicked: quickSetupDialog.open()
                    }
                }

                DeviceTile {
                    objectName: "remoteServiceRow"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    tokens: root.tokens
                    focusTile: root.bridgeActionVisible()
                    iconName: "remote"
                    titleText: qsTr("遥控器服务")
                    descriptionText: qsTr("连接遥控器，接收按键和语音")
                    stateText: root.bridgeStateText()
                    stateColor: root.bridgeStateColor()

                    CompactButton {
                        objectName: "stopBridgeButton"
                        visible: SettingsController.bridgeRunning
                            && !SettingsController.bridgeReconnectBusy
                            && (SettingsController.bridgeLaunchPhase === "stopping"
                                || !SettingsController.bridgeLaunchBusy)
                        tokens: root.tokens
                        flat: true
                        text: SettingsController.bridgeLaunchPhase === "stopping"
                            ? qsTr("停止中…") : qsTr("关闭服务")
                        enabled: SettingsController.bridgeLaunchPhase !== "stopping"
                            && !SettingsController.bridgeLaunchBusy
                            && !SettingsController.configurationReadOnly
                            && !DiagnosticsController.vbCableTestRunning
                            && !DiagnosticsController.driverActionRunning
                            && !SettingsController.voiceHotkeyBusy
                            && !SettingsController.endpointPreflightBusy
                        onClicked: stopBridgeConfirmDialog.open()
                    }

                    CompactButton {
                        objectName: "bridgeActionButton"
                        visible: root.bridgeActionVisible()
                        tokens: root.tokens
                        highlighted: true
                        text: root.bridgeActionText()
                        enabled: !SettingsController.bridgeLaunchBusy
                            && !SettingsController.configurationReadOnly
                            && (SettingsController.bridgeRunning || !SettingsController.activeRemoteKey
                                || SettingsController.activeRemoteReady)
                            && !SettingsController.bridgeReconnectBusy
                            && !DiagnosticsController.vbCableTestRunning
                            && !DiagnosticsController.driverActionRunning
                            && !SettingsController.voiceHotkeyBusy
                            && !SettingsController.endpointPreflightBusy
                        onClicked: {
                            if (!SettingsController.bridgeRunning)
                                SettingsController.startBridge()
                            else if (root.sourceAuthorizationRetryAvailable() || root.bridgeNeedsRestartAction())
                                SettingsController.restartBridge()
                            else if (root.bridgeReconnectActionAvailable())
                                SettingsController.reconnectBridgeNow()
                        }
                    }
                }

                DeviceTile {
                    objectName: "runtimeLogRow"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 0
                    tokens: root.tokens
                    iconName: "refresh"
                    titleText: qsTr("检查更新")
                    descriptionText: qsTr("有新版本时在这里提示")
                    stateText: SettingsController.applicationUpdateCanDownload
                        ? qsTr("有新版本") : ""
                    stateColor: root.tokens.accent

                    CompactButton {
                        id: deviceUsageLink
                        objectName: "deviceUsageLink"
                        tokens: root.tokens
                        flat: true
                        text: qsTr("关于")
                        KeyNavigation.tab: checkApplicationUpdateButton
                        onClicked: aboutDialog.open()
                    }
                    CompactButton {
                        id: checkApplicationUpdateButton
                        objectName: "checkApplicationUpdateButton"
                        tokens: root.tokens
                        text: SettingsController.applicationUpdateCheckBusy
                            ? qsTr("检查中…")
                            : (SettingsController.applicationUpdateCanDownload
                                ? qsTr("查看更新") : qsTr("检查更新"))
                        enabled: !SettingsController.applicationUpdateBusy
                        KeyNavigation.backtab: deviceUsageLink
                        KeyNavigation.tab: launchAtLoginSwitch
                        onClicked: {
                            if (SettingsController.applicationUpdateCanDownload)
                                SettingsController.showApplicationUpdate()
                            else
                                SettingsController.checkForApplicationUpdate()
                        }
                    }
                }
            }

            // ── 通用设置 ──
            SectionFrame {
                objectName: "desktopBehaviorSection"
                tokens: root.tokens
                Layout.fillWidth: true
                Layout.topMargin: 20
                titleText: qsTr("通用设置")
                titleObjectName: "desktopBehaviorSectionTitle"
                titleActions: CompactLink {
                    objectName: "deviceRetrySaveLink"
                    tokens: root.tokens
                    text: qsTr("重试保存")
                    visible: SettingsController.mappingAutoSaveRetryAvailable
                    onClicked: SettingsController.retryMappingAutoSave()
                }

                Row {
                    id: generalDualRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    Item {
                        width: Math.floor((generalDualRow.width - 1) / 2)
                        height: generalDualRow.height

                        SettingCell {
                            objectName: "launchAtLoginRow"
                            anchors.fill: parent
                            anchors.rightMargin: 16
                            tokens: root.tokens
                            titleText: qsTr("随 Windows 启动")
                            descriptionText: qsTr("登录后后台运行")

                            CompactSwitch {
                                id: launchAtLoginSwitch
                                objectName: "launchAtLoginSwitch"
                                tokens: root.tokens
                                checked: SettingsController.launchAtLogin
                                Accessible.name: qsTr("随 Windows 启动")
                                onToggled: {
                                    if (checked !== SettingsController.launchAtLogin)
                                        SettingsController.setLaunchAtLogin(checked)
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: root.tokens.border
                    }

                    Item {
                        width: Math.ceil((generalDualRow.width - 1) / 2)
                        height: generalDualRow.height

                        SettingCell {
                            objectName: "launchBridgeOnAppStartRow"
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            tokens: root.tokens
                            titleText: qsTr("启动程序时自动运行服务")
                            descriptionText: qsTr("自动连接遥控器")
                            enabled: !SettingsController.configurationReadOnly

                            CompactSwitch {
                                id: launchBridgeOnAppStartSwitch
                                objectName: "launchBridgeOnAppStartSwitch"
                                tokens: root.tokens
                                checked: SettingsController.launchBridgeOnAppStart
                                Accessible.name: qsTr("启动程序时自动运行遥控器服务")
                                onToggled: {
                                    if (checked !== SettingsController.launchBridgeOnAppStart)
                                        SettingsController.setLaunchBridgeOnAppStart(checked)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: tokens.hairlineWidth
                    color: root.tokens.border
                }

                Row {
                    id: generalSecondRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    Item {
                        width: Math.floor((generalSecondRow.width - 1) / 2)
                        height: generalSecondRow.height

                        SettingCell {
                            objectName: "closeBehaviorRow"
                            anchors.fill: parent
                            anchors.rightMargin: 16
                            tokens: root.tokens
                            titleText: qsTr("关闭窗口时隐藏到任务栏")
                            descriptionText: qsTr("保留右下角图标")

                            CompactSwitch {
                                id: closeBehaviorSwitch
                                objectName: "closeBehaviorSwitch"
                                tokens: root.tokens
                                checked: SettingsController.closeBehavior !== "quit"
                                Accessible.name: qsTr("关闭窗口时隐藏到任务栏")
                                onToggled: SettingsController.setCloseBehaviorIndex(checked ? 0 : 1)
                                KeyNavigation.tab: root.tabTarget
                            }
                        }
                    }

                    Rectangle {
                        width: 1
                        height: parent.height
                        color: root.tokens.border
                    }

                    Item {
                        width: Math.ceil((generalSecondRow.width - 1) / 2)
                        height: generalSecondRow.height

                        SettingCell {
                            objectName: "appearanceRow"
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            tokens: root.tokens
                            titleText: qsTr("外观")
                            descriptionText: qsTr("界面主题")

                            ChipGroup {
                                objectName: "appearanceChips"
                                tokens: root.tokens
                                model: [qsTr("跟随系统"), qsTr("浅色"), qsTr("深色")]
                                currentIndex: root.tokens.themeMode
                                onActivated: function(index) { root.tokens.setThemeMode(index) }
                            }
                        }
                    }
                }
            }

            // ── 软件协助 ──
            SectionFrame {
                objectName: "softwareAssistSection"
                tokens: root.tokens
                Layout.fillWidth: true
                Layout.topMargin: 12
                titleText: qsTr("软件协助")
                titleObjectName: "softwareAssistSectionTitle"

                SettingRow {
                    objectName: "diagnosticTraceRow"
                    tokens: root.tokens
                    Layout.fillWidth: true
                    inlineLabel: true
                    showDivider: false
                    titleText: qsTr("诊断日志")
                    descriptionText: qsTr("记录按键与语音排查信息，本地保存")

                    CompactButton {
                        id: deviceHelpCenterButton
                        objectName: "deviceHelpCenterButton"
                        tokens: root.tokens
                        flat: true
                        trailingIcon: "external"
                        text: qsTr("查看帮助")
                        Accessible.name: qsTr("打开帮助页面")
                        KeyNavigation.backtab: launchBridgeOnAppStartSwitch
                        KeyNavigation.tab: deviceLogLocationLink
                        onClicked: SettingsController.openHelpCenter()
                    }
                    CompactButton {
                        id: deviceLogLocationLink
                        objectName: "deviceLogLocationLink"
                        tokens: root.tokens
                        flat: true
                        text: qsTr("打开日志位置")
                        KeyNavigation.backtab: deviceHelpCenterButton
                        KeyNavigation.tab: deviceOpenLogButton
                        onClicked: SettingsController.openLogLocation()
                    }
                    CompactButton {
                        id: deviceOpenLogButton
                        objectName: "deviceOpenLogButton"
                        tokens: root.tokens
                        flat: true
                        text: SettingsController.logExportBusy ? qsTr("导出中…") : qsTr("导出日志")
                        enabled: !SettingsController.logExportBusy
                        KeyNavigation.backtab: deviceLogLocationLink
                        KeyNavigation.tab: diagnosticTraceSwitch
                        onClicked: {
                            logExportDialog.selectedFile = SettingsController.logExportDefaultFile()
                            logExportDialog.open()
                        }
                    }
                    CompactSwitch {
                        id: diagnosticTraceSwitch
                        objectName: "diagnosticTraceSwitch"
                        enabled: !SettingsController.configurationReadOnly
                        tokens: root.tokens
                        checked: SettingsController.diagnosticTraceEnabled
                        Accessible.name: qsTr("诊断日志")
                        KeyNavigation.backtab: deviceOpenLogButton
                        onToggled: {
                            if (checked !== SettingsController.diagnosticTraceEnabled)
                                SettingsController.setDiagnosticTraceEnabled(checked)
                        }
                    }
                }
            }
        }
    }

    // 功能瓦片：图标 + 右上操作 + 标题 + 说明
    component DeviceTile: Rectangle {
        id: tile

        property var tokens
        property string iconName: ""
        property string titleText: ""
        property string descriptionText: ""
        property string stateText: ""
        property color stateColor: tokens.successColor
        property bool focusTile: false
        default property alias actions: tileActions.data

        implicitHeight: 119
        radius: tokens.cornerRadiusCard
        color: focusTile ? tokens.accentSoft : tokens.surface
        border.width: 1
        border.color: focusTile ? tokens.accentLine : tokens.border

        // .tile：padding 14 14 12 16；.tile-top 32 高，两端对齐
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: 14
            anchors.bottomMargin: 12
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                spacing: 4

                Rectangle {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    radius: 10
                    color: tile.focusTile ? tokens.accent : tokens.surfaceMuted

                    SvgIcon {
                        anchors.centerIn: parent
                        name: tile.iconName
                        size: 18
                        color: tile.focusTile ? tokens.accentText : tokens.textSecondary
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    id: tileActions
                    spacing: 4
                }
            }

            Label {
                objectName: tile.objectName.length > 0
                    ? tile.objectName + "_titleLabel" : ""
                Layout.topMargin: 10
                Layout.fillWidth: true
                text: tile.titleText
                font.family: tokens.fontFamily
                font.pixelSize: tokens.fontSizeSection
                font.weight: Font.DemiBold
                lineHeight: 20
                lineHeightMode: Text.FixedHeight
                color: tokens.textPrimary
                elide: Text.ElideRight
            }
            // 稿里瓦片不显示状态字，仅保留给辅助功能/测试读取
            Label {
                objectName: tile.objectName.length > 0
                    ? tile.objectName + "_stateLabel" : ""
                visible: false
                text: tile.stateText
            }

            Label {
                objectName: tile.objectName.length > 0
                    ? tile.objectName + "_descriptionLabel" : ""
                lineHeight: 16
                lineHeightMode: Text.FixedHeight
                text: tile.descriptionText
                font.family: tokens.fontFamily
                font.pixelSize: 12
                color: tokens.textTertiary
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }
        }
    }

    // CSS radial-gradient 的椭圆径向渐变：Qt Shape 的 RadialGradient 只能画正圆，
    // 这里先把形状按半径比例画成正圆，再对 Shape 做纵向缩放，渐变随之变成椭圆。
    component HeroGlow: Shape {
        id: heroGlow
        required property Rectangle hero
        // 渐变中心相对卡片宽/高的比例（对应 CSS 的 at x% y%）
        required property real centerXFactor
        required property real centerYFactor
        // 椭圆半径相对卡片宽/高的比例（对应 CSS 的 120% 140%）
        required property real radiusXFactor
        required property real radiusYFactor
        // 相对半径的衰减位置（对应 CSS 的 transparent 55%）
        property real edgePosition: 0.55
        property color glowColor: "#21ffffff"

        preferredRendererType: Shape.CurveRenderer
        readonly property real radiusX: hero.width * radiusXFactor
        readonly property real radiusY: hero.height * radiusYFactor
        readonly property real yScale: radiusX > 0 ? radiusY / radiusX : 1
        readonly property real cornerX: hero.radius
        readonly property real cornerY: yScale > 0 ? hero.radius / yScale : hero.radius

        width: hero.width
        height: hero.height / yScale
        transform: Scale {
            origin.x: 0
            origin.y: 0
            yScale: heroGlow.yScale
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: heroGlow.width * heroGlow.centerXFactor
                centerY: heroGlow.height * heroGlow.centerYFactor
                centerRadius: heroGlow.radiusX
                // QtQuick.Shapes 的 RadialGradient 焦点默认在 (0,0) 而不是圆心，
                // 不显式对齐的话渐变会变成左上角顶出来的一道锥形。
                focalX: centerX
                focalY: centerY
                focalRadius: 0
                GradientStop { position: 0.0; color: heroGlow.glowColor }
                GradientStop { position: heroGlow.edgePosition; color: "#00ffffff" }
            }
            // 柔光层必须和卡片同样圆角，否则亮部所在的左上/右下会露出直角。
            // Shape 之后会纵向缩放 yScale，所以竖直方向的圆角半径要先除以 yScale。
            startX: heroGlow.cornerX
            startY: 0
            PathLine { x: heroGlow.width - heroGlow.cornerX; y: 0 }
            PathArc {
                x: heroGlow.width; y: heroGlow.cornerY
                radiusX: heroGlow.cornerX; radiusY: heroGlow.cornerY
            }
            PathLine { x: heroGlow.width; y: heroGlow.height - heroGlow.cornerY }
            PathArc {
                x: heroGlow.width - heroGlow.cornerX; y: heroGlow.height
                radiusX: heroGlow.cornerX; radiusY: heroGlow.cornerY
            }
            PathLine { x: heroGlow.cornerX; y: heroGlow.height }
            PathArc {
                x: 0; y: heroGlow.height - heroGlow.cornerY
                radiusX: heroGlow.cornerX; radiusY: heroGlow.cornerY
            }
            PathLine { x: 0; y: heroGlow.cornerY }
            PathArc {
                x: heroGlow.cornerX; y: 0
                radiusX: heroGlow.cornerX; radiusY: heroGlow.cornerY
            }
        }
    }
}
