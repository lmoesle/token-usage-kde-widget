import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    property alias cfg_command: commandField.text

    Kirigami.FormLayout {
        anchors.fill: parent

        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: i18n("Base command:")
            placeholderText: i18n("token-usage")
        }
    }
}
