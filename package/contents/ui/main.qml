import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    width: Kirigami.Units.gridUnit * 20
    height: Kirigami.Units.gridUnit * 10

    Layout.minimumWidth: Kirigami.Units.gridUnit * 10
    Layout.minimumHeight: Kirigami.Units.gridUnit * 4

    Plasmoid.icon: "office-chart-line"
    toolTipMainText: i18n("lmoesle-token-usage")
    toolTipSubText: root.statusText

    property string stdoutText: ""
    property string stderrText: ""
    property string commandErrorText: ""
    property string updatedAtText: ""
    property string runningSourceName: ""
    property bool commandRunning: false
    property int lastExitCode: 0

    readonly property string command: root.normalizeCommand(plasmoid.configuration.command)
    readonly property int refreshIntervalSeconds: Math.max(30, plasmoid.configuration.refreshIntervalSeconds || 300)
    readonly property int commandTimeoutSeconds: 60
    readonly property bool hasError: root.commandErrorText.length > 0 || root.lastExitCode !== 0
    readonly property string displayedText: root.formatDisplayedText()
    readonly property string statusText: root.commandRunning
        ? i18n("Updating...")
        : root.hasError
            ? root.firstLine(root.commandErrorText.length > 0 ? root.commandErrorText : root.stderrText)
            : root.updatedAtText.length > 0
                ? i18n("Updated %1", root.updatedAtText)
                : i18n("Not updated yet")

    function normalizeCommand(value) {
        return value === undefined || value === null ? "token-usage" : String(value).trim()
    }

    function formatDisplayedText() {
        var parts = []
        var stdout = root.stdoutText.trim()
        var stderr = root.stderrText.trim()

        if (root.commandErrorText.length > 0) {
            parts.push(root.commandErrorText)
        }

        if (stdout.length > 0) {
            parts.push(stdout)
        }

        if (stderr.length > 0) {
            parts.push(i18n("stderr:") + "\n" + stderr)
        }

        if (root.lastExitCode !== 0) {
            parts.push(i18n("Exit code: %1", root.lastExitCode))
        }

        return parts.length > 0 ? parts.join("\n\n") : i18n("Waiting for token usage data...")
    }

    function firstLine(value) {
        var text = (value || "").trim()
        if (text.length === 0) {
            return i18n("Token usage")
        }

        var lineBreak = text.search(/\r?\n/)
        return lineBreak === -1 ? text : text.slice(0, lineBreak)
    }

    function refresh() {
        if (root.commandRunning) {
            return
        }

        if (root.command.length === 0) {
            root.commandErrorText = i18n("No token-usage command configured.")
            root.stdoutText = ""
            root.stderrText = ""
            root.lastExitCode = 0
            root.updatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
            return
        }

        root.commandRunning = true
        root.commandErrorText = ""
        root.runningSourceName = root.command
        commandTimeoutTimer.restart()
        executableSource.connectSource(root.command)
    }

    function handleCommandResult(sourceName, data) {
        if (!root.commandRunning || sourceName !== root.runningSourceName) {
            executableSource.disconnectSource(sourceName)
            return
        }

        executableSource.disconnectSource(sourceName)
        commandTimeoutTimer.stop()
        root.commandRunning = false
        root.runningSourceName = ""
        root.updatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")

        root.lastExitCode = Number(data["exit code"] || 0)
        root.stdoutText = data["stdout"] || ""
        root.stderrText = data["stderr"] || ""
        root.commandErrorText = root.lastExitCode !== 0 && root.stderrText.trim().length === 0
            ? i18n("Command exited with code %1.", root.lastExitCode)
            : ""
    }

    function handleCommandTimeout() {
        if (!root.commandRunning) {
            return
        }

        executableSource.disconnectSource(root.runningSourceName)
        root.commandRunning = false
        root.runningSourceName = ""
        root.stdoutText = ""
        root.stderrText = ""
        root.lastExitCode = 0
        root.commandErrorText = i18n("Command timed out after %1 seconds.", root.commandTimeoutSeconds)
        root.updatedAtText = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }

    compactRepresentation: MouseArea {
        id: compactRepresentation

        implicitWidth: Math.min(compactLayout.implicitWidth, Kirigami.Units.gridUnit * 14)
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Layout.preferredWidth: compactRepresentation.implicitWidth
        Layout.preferredHeight: compactRepresentation.implicitHeight

        hoverEnabled: true
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactLayout

            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: plasmoid.icon
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter
            }

            PlasmaComponents.Label {
                text: root.commandRunning ? i18n("Updating...") : root.firstLine(root.displayedText)
                maximumLineCount: 1
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 12
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    fullRepresentation: Item {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 12

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
                    running: root.commandRunning
                    visible: root.commandRunning
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }

                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    text: i18n("Refresh")
                    enabled: !root.commandRunning
                    onClicked: root.refresh()
                }
            }

            PlasmaComponents.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                PlasmaComponents.TextArea {
                    text: root.displayedText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: root.hasError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    font.family: "monospace"
                }
            }

            PlasmaComponents.Label {
                text: root.updatedAtText.length > 0
                    ? i18n("Updated: %1", root.updatedAtText)
                    : i18n("Command: %1", root.command)
                opacity: 0.75
                maximumLineCount: 1
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    Plasma5Support.DataSource {
        id: executableSource
        engine: "executable"

        onNewData: function(sourceName, data) {
            root.handleCommandResult(sourceName, data)
        }
    }

    Timer {
        interval: root.refreshIntervalSeconds * 1000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        id: commandTimeoutTimer
        interval: root.commandTimeoutSeconds * 1000
        repeat: false
        onTriggered: root.handleCommandTimeout()
    }

    Component.onCompleted: root.refresh()
}
