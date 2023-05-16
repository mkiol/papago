/* Copyright (C) 2023 Michal Kosciesza <michal@mkiol.net>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0

ApplicationWindow {
    id: app

    property alias speechStatus: speechService.speech
    property alias speechText: label.text
    property alias speechLang: speechService.lang
    property bool speechOff: app.speechLang.length === 0

    Component {
        id: coverComp
        CoverBackground {
            CoverPlaceholder {
                 icon.source: "/usr/share/icons/hicolor/172x172/apps/harbour-papago.png"
                 text: "Papago"
            }
        }
    }

    cover: coverComp

    allowedOrientations: defaultAllowedOrientations

    initialPage: Page {
        allowedOrientations: Orientation.All

        ComboBox {
            visible: !app.speechOff
            label: qsTr("Language")
            currentIndex: 0
            menu: ContextMenu {
                Repeater {
                    model: speechService.sttTtsLangList
                    MenuItem {
                        text: modelData[1]
                    }
                }
            }

            onCurrentIndexChanged: {
                speechService.set_lang(currentIndex)
                label.text = ""
            }
        }

        Label {
            visible: app.speechOff
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Theme.errorColor
            wrapMode: Text.WordWrap
            text: qsTr("No language is available.") + " " +
                  qsTr("You can set the available languages in the %1 app").arg("Speech Note")
        }

        Label {
            id: label
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Theme.highlightColor
            wrapMode: Text.WordWrap
        }

        Label {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.horizontalPageMargin
            anchors.rightMargin: Theme.horizontalPageMargin
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryHighlightColor
            wrapMode: Text.WordWrap
            text: {
                if (app.speechStatus === 2) return speechService.translate("decoding")
                if (app.speechStatus === 3) return speechService.translate("initializing")
                return speechService.translate("say_smth");
            }
            visible: app.speechText.length === 0 && !app.speechOff && !speechService.busy
        }

        SpeechIndicator {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.itemSizeLarge
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.itemSizeSmall
            color: speechService.playing ? Theme.highlightColor : Theme.secondaryHighlightColor
            status: app.speechStatus
            off: app.speechOff
            visible: opacity > 0.0
            opacity: speechService.busy ? 0.0 : 1.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        BusyIndicator {
            size: BusyIndicatorSize.Large
            anchors.centerIn: parent
            running: speechService.busy
        }
    }

    SpeechService {
        id: speechService

        property string lang: ""
        property string decodedText: ""

        function init() {
            if (idle && lang.length > 0) {
                if (decodedText.length === 0) {
                    startListen(lang)
                } else {
                    playSpeech(decodedText, lang)
                    decodedText = ""
                }
            } else {
                cancel()
            }
        }

        function set_lang(index) {
            decodedText = ""

            if (index < sttTtsLangList.length)
                lang = sttTtsLangList[index][0]
        }

        active: true
        listeningMode: 2 /*One Sentence*/

        onLangChanged: init()

        onSttTtsLangListChanged: set_lang(0)

        onTextReady: {
            decodedText = text
            label.text = text
        }

        onIntermediateTextReady: {
            if (text.length > 0)
                label.text = text
        }

        onPlaySpeechFinished: {
            decodedText = ""
            label.text = ""
        }

        onIdleChanged: {
            if (idle) init()
        }
    }
}
