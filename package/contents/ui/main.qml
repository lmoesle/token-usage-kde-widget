import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 48
    height: Kirigami.Units.gridUnit * 24

    Layout.minimumWidth: Kirigami.Units.gridUnit * 32
    Layout.minimumHeight: Kirigami.Units.gridUnit * 14

    Plasmoid.icon: "office-chart-line"
    toolTipMainText: i18n("Token Usage")
    toolTipSubText: root.todayErrorText.length > 0
        ? root.todayErrorText
        : root.todayCostText.length > 0
            ? i18n("Today: %1", root.todayCostText)
            : i18n("Loading today's token usage...")

    property var periods: ["today", "weekly", "monthly", "yearly"]
    property string activePeriod: "today"
    property string activeErrorText: ""
    property string activeUpdatedAtText: ""
    property string todayCostText: ""
    property string todayErrorText: ""
    property string todayUpdatedAtText: ""
    property string runningTodaySourceName: ""
    property string runningPeriodSourceName: ""
    property string runningPeriod: ""
    property bool todayRunning: false
    property bool periodRunning: false

    readonly property string baseCommand: root.normalizeBaseCommand(plasmoid.configuration.command)
    readonly property int todayRefreshIntervalSeconds: 30
    readonly property int commandTimeoutSeconds: 60
    readonly property bool activeRunning: root.activePeriod === "today" ? root.todayRunning : root.periodRunning
    readonly property string compactText: root.todayErrorText.length > 0
        ? i18n("ERR 🔥")
        : root.todayCostText.length > 0
            ? i18n("%1 🔥", root.todayCostText)
            : root.todayRunning
                ? i18n("... 🔥")
                : i18n("ERR 🔥")

    readonly property int periodColumnWidth: Kirigami.Units.gridUnit * 7
    readonly property int agentColumnWidth: Kirigami.Units.gridUnit * 7
    readonly property int modelColumnWidth: Kirigami.Units.gridUnit * 11
    readonly property int numberColumnWidth: Kirigami.Units.gridUnit * 6
    readonly property int costColumnWidth: Kirigami.Units.gridUnit * 5
    readonly property int tableWidth: root.periodColumnWidth
        + root.agentColumnWidth
        + root.modelColumnWidth
        + root.numberColumnWidth * 4
        + root.costColumnWidth
        + Kirigami.Units.smallSpacing * 7

    component TableCell: PlasmaComponents.Label {
        property int cellWidth: Kirigami.Units.gridUnit * 6

        Layout.minimumWidth: cellWidth
        Layout.preferredWidth: cellWidth
        Layout.maximumWidth: cellWidth
        maximumLineCount: 1
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    ListModel {
        id: entriesModel
    }

    function normalizeBaseCommand(value) {
        return value === undefined || value === null ? "token-usage" : String(value).trim()
    }

    function buildCommand(period) {
        return root.baseCommand + " " + period + " --raw"
    }

    function periodTitle(period) {
        if (period === "today") {
            return i18n("Today")
        }
        if (period === "weekly") {
            return i18n("Weekly")
        }
        if (period === "monthly") {
            return i18n("Monthly")
        }
        if (period === "yearly") {
            return i18n("Yearly")
        }

        return period
    }

    function formatInteger(value) {
        var number = Math.round(Number(value) || 0)
        var sign = number < 0 ? "-" : ""
        var text = Math.abs(number).toString()
        return sign + text.replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    function formatCost(value) {
        var number = Number(value)
        if (!isFinite(number)) {
            number = 0
        }

        return "$" + number.toFixed(2)
    }

    function tokenUsageSetupHelp() {
        return i18n("Plasma does not load aliases from .bashrc. Create a real token-usage executable that Plasma can run:")
            + "\n\n"
            + "mkdir -p ~/.local/bin\n"
            + "printf '%s\\n' '#!/usr/bin/env sh' 'exec /home/lmoesle/.nvm/versions/node/v24.16.0/bin/npx --yes @lmoesle/token-usage-cli \"$@\"' > ~/.local/bin/token-usage\n"
            + "chmod +x ~/.local/bin/token-usage"
    }

    function isCommandNotFound(exitCode, message) {
        var lowerMessage = String(message || "").toLowerCase()
        return exitCode === 127
            || lowerMessage.indexOf("command not found") !== -1
            || lowerMessage.indexOf("not found") !== -1
            || lowerMessage.indexOf("not resolved") !== -1
    }

    function noCommandConfiguredText() {
        return i18n("No token-usage command configured.") + "\n\n" + root.tokenUsageSetupHelp()
    }

    function commandFailure(data) {
        var exitCode = Number(data["exit code"] || 0)
        if (exitCode === 0) {
            return ""
        }

        var stderr = String(data["stderr"] || "").trim()
        var message = stderr.length > 0 ? stderr : i18n("Command exited with code %1.", exitCode)
        return root.isCommandNotFound(exitCode, message)
            ? message + "\n\n" + root.tokenUsageSetupHelp()
            : message
    }

    function parsePayload(stdout, period) {
        var text = String(stdout || "").trim()
        if (text.length === 0) {
            return {
                error: i18n("%1 produced no JSON output.", root.buildCommand(period))
            }
        }

        try {
            var payload = JSON.parse(text)
            if (!payload || typeof payload !== "object") {
                return {
                    error: i18n("%1 returned invalid JSON.", root.buildCommand(period))
                }
            }

            if (!Array.isArray(payload.entries)) {
                return {
                    error: i18n("%1 returned JSON without an entries array.", root.buildCommand(period))
                }
            }

            if (!payload.total || typeof payload.total !== "object") {
                return {
                    error: i18n("%1 returned JSON without a total object.", root.buildCommand(period))
                }
            }

            for (var index = 0; index < payload.entries.length; index += 1) {
                if (!payload.entries[index] || typeof payload.entries[index] !== "object") {
                    return {
                        error: i18n("%1 returned an invalid entry at row %2.", root.buildCommand(period), index + 1)
                    }
                }
            }

            return {
                payload: payload
            }
        } catch (error) {
            return {
                error: i18n("Could not parse %1 output as JSON: %2", root.buildCommand(period), error.message)
            }
        }
    }

    function appendTableEntry(period, entry, totalRow) {
        entriesModel.append({
            periodLabel: totalRow ? i18n("Total") : String(entry.date || period),
            agentName: totalRow ? "" : String(entry.agent || ""),
            modelName: totalRow ? "" : String(entry.model || ""),
            inputTokens: root.formatInteger(entry.inputTokens),
            outputTokens: root.formatInteger(entry.outputTokens),
            cachedTokens: root.formatInteger(entry.cachedTokens),
            totalTokens: root.formatInteger(entry.totalTokens),
            cost: root.formatCost(entry.cost),
            totalRow: totalRow
        })
    }

    function populateTable(period, payload) {
        entriesModel.clear()

        for (var index = 0; index < payload.entries.length; index += 1) {
            root.appendTableEntry(period, payload.entries[index], false)
        }

        root.appendTableEntry(period, payload.total, true)

        root.activeErrorText = ""
        root.activeUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }

    function selectPeriod(period) {
        root.activePeriod = period
        root.refreshActivePeriod()
    }

    function refreshActivePeriod() {
        if (root.activePeriod === "today") {
            root.refreshToday(true)
            return
        }

        root.refreshPeriod(root.activePeriod)
    }

    function refreshToday(force) {
        if (root.todayRunning) {
            if (!force) {
                return
            }

            todaySource.disconnectSource(root.runningTodaySourceName)
            todayTimeoutTimer.stop()
            root.todayRunning = false
        }

        if (root.baseCommand.length === 0) {
            root.todayErrorText = root.noCommandConfiguredText()
            root.todayUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
            if (root.activePeriod === "today") {
                root.activeErrorText = root.todayErrorText
                entriesModel.clear()
            }
            return
        }

        root.todayErrorText = ""
        root.todayRunning = true
        root.runningTodaySourceName = root.buildCommand("today")
        todayTimeoutTimer.restart()
        todaySource.connectSource(root.runningTodaySourceName)
    }

    function refreshPeriod(period) {
        if (root.periodRunning) {
            periodSource.disconnectSource(root.runningPeriodSourceName)
            periodTimeoutTimer.stop()
            root.periodRunning = false
        }

        if (root.baseCommand.length === 0) {
            root.activeErrorText = root.noCommandConfiguredText()
            root.activeUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
            entriesModel.clear()
            return
        }

        root.activeErrorText = ""
        root.activeUpdatedAtText = ""
        entriesModel.clear()
        root.periodRunning = true
        root.runningPeriod = period
        root.runningPeriodSourceName = root.buildCommand(period)
        periodTimeoutTimer.restart()
        periodSource.connectSource(root.runningPeriodSourceName)
    }

    function handleTodayResult(sourceName, data) {
        if (!root.todayRunning || sourceName !== root.runningTodaySourceName) {
            todaySource.disconnectSource(sourceName)
            return
        }

        todaySource.disconnectSource(sourceName)
        todayTimeoutTimer.stop()
        root.todayRunning = false
        root.runningTodaySourceName = ""
        root.todayUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")

        var failure = root.commandFailure(data)
        if (failure.length > 0) {
            root.todayErrorText = failure
            if (root.activePeriod === "today") {
                root.activeErrorText = failure
                entriesModel.clear()
            }
            return
        }

        var parsed = root.parsePayload(data["stdout"], "today")
        if (parsed.error) {
            root.todayErrorText = parsed.error
            if (root.activePeriod === "today") {
                root.activeErrorText = parsed.error
                entriesModel.clear()
            }
            return
        }

        root.todayCostText = root.formatCost(parsed.payload.total ? parsed.payload.total.cost : 0)
        root.todayErrorText = ""

        if (root.activePeriod === "today") {
            root.populateTable("today", parsed.payload)
        }
    }

    function handlePeriodResult(sourceName, data) {
        if (!root.periodRunning || sourceName !== root.runningPeriodSourceName) {
            periodSource.disconnectSource(sourceName)
            return
        }

        var period = root.runningPeriod
        periodSource.disconnectSource(sourceName)
        periodTimeoutTimer.stop()
        root.periodRunning = false
        root.runningPeriod = ""
        root.runningPeriodSourceName = ""

        if (root.activePeriod !== period) {
            return
        }

        var failure = root.commandFailure(data)
        if (failure.length > 0) {
            root.activeErrorText = failure
            root.activeUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
            entriesModel.clear()
            return
        }

        var parsed = root.parsePayload(data["stdout"], period)
        if (parsed.error) {
            root.activeErrorText = parsed.error
            root.activeUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
            entriesModel.clear()
            return
        }

        root.populateTable(period, parsed.payload)
    }

    function handleTodayTimeout() {
        if (!root.todayRunning) {
            return
        }

        todaySource.disconnectSource(root.runningTodaySourceName)
        root.todayRunning = false
        root.runningTodaySourceName = ""
        root.todayErrorText = i18n("Today command timed out after %1 seconds.", root.commandTimeoutSeconds)
        root.todayUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
        if (root.activePeriod === "today") {
            root.activeErrorText = root.todayErrorText
            entriesModel.clear()
        }
    }

    function handlePeriodTimeout() {
        if (!root.periodRunning) {
            return
        }

        periodSource.disconnectSource(root.runningPeriodSourceName)
        var period = root.runningPeriod
        root.periodRunning = false
        root.runningPeriod = ""
        root.runningPeriodSourceName = ""
        if (root.activePeriod !== period) {
            return
        }

        root.activeErrorText = i18n("%1 command timed out after %2 seconds.", root.periodTitle(root.activePeriod), root.commandTimeoutSeconds)
        root.activeUpdatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
        entriesModel.clear()
    }

    compactRepresentation: MouseArea {
        id: compactRepresentation

        implicitWidth: compactLabel.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: Math.max(compactLabel.implicitHeight, Kirigami.Units.iconSizes.smallMedium)

        Layout.preferredWidth: compactRepresentation.implicitWidth
        Layout.preferredHeight: compactRepresentation.implicitHeight

        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        PlasmaComponents.Label {
            id: compactLabel

            anchors.centerIn: parent
            text: root.compactText
            font.bold: true
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 34
        Layout.minimumHeight: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: root.tableWidth + Kirigami.Units.largeSpacing * 2
        Layout.preferredHeight: Kirigami.Units.gridUnit * 25

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    text: i18n("Token Usage")
                    level: 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.BusyIndicator {
                    running: root.activeRunning
                    visible: root.activeRunning
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    enabled: !root.activeRunning
                    onClicked: root.refreshActivePeriod()
                }
            }

            PlasmaComponents.TabBar {
                Layout.fillWidth: true

                PlasmaComponents.TabButton {
                    text: i18n("Today")
                    onClicked: root.selectPeriod("today")
                }

                PlasmaComponents.TabButton {
                    text: i18n("Weekly")
                    onClicked: root.selectPeriod("weekly")
                }

                PlasmaComponents.TabButton {
                    text: i18n("Monthly")
                    onClicked: root.selectPeriod("monthly")
                }

                PlasmaComponents.TabButton {
                    text: i18n("Yearly")
                    onClicked: root.selectPeriod("yearly")
                }
            }

            PlasmaComponents.Label {
                visible: root.activeErrorText.length > 0
                text: root.activeErrorText
                color: Kirigami.Theme.negativeTextColor
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            PlasmaComponents.ScrollView {
                id: tableScroll

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: root.tableWidth
                contentHeight: tableContent.implicitHeight

                ColumnLayout {
                    id: tableContent

                    width: root.tableWidth
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        TableCell { text: i18n("Period"); cellWidth: root.periodColumnWidth; font.bold: true }
                        TableCell { text: i18n("Agent"); cellWidth: root.agentColumnWidth; font.bold: true }
                        TableCell { text: i18n("Model"); cellWidth: root.modelColumnWidth; font.bold: true }
                        TableCell { text: i18n("Input"); cellWidth: root.numberColumnWidth; font.bold: true; horizontalAlignment: Text.AlignRight }
                        TableCell { text: i18n("Output"); cellWidth: root.numberColumnWidth; font.bold: true; horizontalAlignment: Text.AlignRight }
                        TableCell { text: i18n("Cached"); cellWidth: root.numberColumnWidth; font.bold: true; horizontalAlignment: Text.AlignRight }
                        TableCell { text: i18n("Total"); cellWidth: root.numberColumnWidth; font.bold: true; horizontalAlignment: Text.AlignRight }
                        TableCell { text: i18n("Cost"); cellWidth: root.costColumnWidth; font.bold: true; horizontalAlignment: Text.AlignRight }
                    }

                    Rectangle {
                        color: Kirigami.Theme.disabledTextColor
                        opacity: 0.35
                        implicitHeight: 1
                        Layout.fillWidth: true
                    }

                    Repeater {
                        model: entriesModel

                        delegate: Item {
                            id: rowDelegate

                            required property string periodLabel
                            required property string agentName
                            required property string modelName
                            required property string inputTokens
                            required property string outputTokens
                            required property string cachedTokens
                            required property string totalTokens
                            required property string cost
                            required property bool totalRow

                            implicitHeight: rowLayout.implicitHeight
                            Layout.fillWidth: true

                            RowLayout {
                                id: rowLayout

                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: Kirigami.Units.smallSpacing

                                TableCell { text: rowDelegate.periodLabel; cellWidth: root.periodColumnWidth; font.bold: rowDelegate.totalRow }
                                TableCell { text: rowDelegate.agentName; cellWidth: root.agentColumnWidth; font.bold: rowDelegate.totalRow }
                                TableCell { text: rowDelegate.modelName; cellWidth: root.modelColumnWidth; font.bold: rowDelegate.totalRow }
                                TableCell { text: rowDelegate.inputTokens; cellWidth: root.numberColumnWidth; font.bold: rowDelegate.totalRow; horizontalAlignment: Text.AlignRight }
                                TableCell { text: rowDelegate.outputTokens; cellWidth: root.numberColumnWidth; font.bold: rowDelegate.totalRow; horizontalAlignment: Text.AlignRight }
                                TableCell { text: rowDelegate.cachedTokens; cellWidth: root.numberColumnWidth; font.bold: rowDelegate.totalRow; horizontalAlignment: Text.AlignRight }
                                TableCell { text: rowDelegate.totalTokens; cellWidth: root.numberColumnWidth; font.bold: rowDelegate.totalRow; horizontalAlignment: Text.AlignRight }
                                TableCell { text: rowDelegate.cost; cellWidth: root.costColumnWidth; font.bold: rowDelegate.totalRow; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        visible: entriesModel.count === 0 && root.activeErrorText.length === 0
                        text: root.activeRunning ? i18n("Loading %1 data...", root.periodTitle(root.activePeriod)) : i18n("No token usage data.")
                        opacity: 0.75
                        Layout.fillWidth: true
                    }
                }
            }

            PlasmaComponents.Label {
                text: root.activeUpdatedAtText.length > 0
                    ? i18n("%1 updated: %2", root.periodTitle(root.activePeriod), root.activeUpdatedAtText)
                    : i18n("Command: %1", root.buildCommand(root.activePeriod))
                opacity: 0.75
                maximumLineCount: 1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    Plasma5Support.DataSource {
        id: todaySource
        engine: "executable"

        onNewData: function(sourceName, data) {
            root.handleTodayResult(sourceName, data)
        }
    }

    Plasma5Support.DataSource {
        id: periodSource
        engine: "executable"

        onNewData: function(sourceName, data) {
            root.handlePeriodResult(sourceName, data)
        }
    }

    Timer {
        interval: root.todayRefreshIntervalSeconds * 1000
        repeat: true
        running: true
        onTriggered: root.refreshToday(false)
    }

    Timer {
        id: todayTimeoutTimer
        interval: root.commandTimeoutSeconds * 1000
        repeat: false
        onTriggered: root.handleTodayTimeout()
    }

    Timer {
        id: periodTimeoutTimer
        interval: root.commandTimeoutSeconds * 1000
        repeat: false
        onTriggered: root.handlePeriodTimeout()
    }

    Component.onCompleted: root.refreshToday(true)
}
