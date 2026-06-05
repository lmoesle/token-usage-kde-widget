import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_command: commandField.text
    property alias cfg_refreshIntervalSeconds: refreshIntervalField.value

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: i18n("Command:")
            placeholderText: i18n("token-usage")
        }

        QQC2.SpinBox {
            id: refreshIntervalField
            Kirigami.FormData.label: i18n("Refresh interval (seconds):")
            editable: true
            from: 30
            to: 86400
            stepSize: 30
        }
    }
}
