/* Copyright (C) 2023 Michal Kosciesza <michal@mkiol.net>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import QtQuick 2.2
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0

ApplicationWindow {
    id: app

    property alias speechStatus: speechService.taskState
    property alias speechInText: inLabel.text
    property alias speechOutText: outLabel.text
    property alias speechInLang: speechService.inLang
    property alias speechOutLang: speechService.outLang
    property bool speechOff: speechInLang.length === 0

    // 0 - idle
    // 1 - listening
    // 2 - text decoded
    // 3 - translating
    // 4 - text translated
    // 5 - playing
    // 6 - play finished
    property int appState: 0

    ConfigurationValue {
        id: inLangConf
        key: "/apps/harbour-papago/settings/inlang"
        defaultValue: "en"

        onValueChanged: {
            speechService.setInLangId(value)
        }
    }

    ConfigurationValue {
        id: outLangConf
        key: "/apps/harbour-papago/settings/outlang"
        defaultValue: "en"

        onValueChanged: {
            speechService.setOutLangId(value)
        }
    }

    ConfigurationValue {
        id: playConf
        key: "/apps/harbour-papago/settings/play"
        defaultValue: false
    }

    ConfigurationValue {
        id: confirmConf
        key: "/apps/harbour-papago/settings/confirm"
        defaultValue: false
    }

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

        Grid {
            id: langGrid

            width: app.orientation & Orientation.PortraitMask ? parent.width : parent.width / 2
            columns: app.orientation & Orientation.PortraitMask ? 1 : 2

            ComboBox {
                id: inLangCombo

                enabled: !speechService.busy && currentIndex !== -1
                opacity: enabled ? 1.0 : Theme.opacityFaint
                Behavior on opacity { FadeAnimator {} }
                visible: !app.speechOff
                label: qsTr("%1 listens").arg("Papago")
                currentIndex: speechService.inLangIdx
                menu: ContextMenu {
                    Repeater {
                        model: speechService.inLangList
                        MenuItem {
                            text: modelData[1]
                        }

                        onItemAdded: updateCurrentIndex()
                        onItemRemoved: updateCurrentIndex()

                        function updateCurrentIndex() {
                            inLangCombo.currentIndex = count > speechService.inLangIdx ?
                                        speechService.inLangIdx : -1
                        }
                    }
                }

                onCurrentIndexChanged: {
                    if (speechService.inLangIdx === currentIndex) return
                    speechService.setInLangIdx(currentIndex)
                }
            }

            ComboBox {
                id: outLangCombo

                enabled: !speechService.busy && inLangCombo.enabled && currentIndex !== -1
                opacity: enabled ? 1.0 : Theme.opacityFaint
                Behavior on opacity { FadeAnimator {} }
                visible: !app.speechOff
                label: qsTr("%1 speeks").arg("Papago")
                currentIndex: speechService.outLangIdx
                menu: ContextMenu {
                    Repeater {
                        model: speechService.outLangList
                        MenuItem {
                            text: modelData[1]
                        }

                        onItemAdded: updateCurrentIndex()
                        onItemRemoved: updateCurrentIndex()

                        function updateCurrentIndex() {
                            outLangCombo.currentIndex = count > speechService.outLangIdx ?
                                        speechService.outLangIdx : -1
                        }
                    }
                }

                onCurrentIndexChanged: {
                    if (speechService.outLangIdx === currentIndex) return
                    speechService.setOutLangIdx(currentIndex)
                }
            }

            ComboBox {
                enabled: !speechService.busy
                opacity: enabled ? 1.0 : Theme.opacityFaint
                Behavior on opacity { FadeAnimator {} }
                visible: !app.speechOff
                label: qsTr("Confirm before speak")
                currentIndex: confirmConf.value ? 1 : 0
                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("No")
                    }
                    MenuItem {
                        text: qsTr("Yes")
                    }
                }

                onCurrentIndexChanged: {
                    confirmConf.value = currentIndex === 1
                }
            }
        }

        IconButton {
            icon.source: (speechService.play ? "image://theme/icon-m-pause?" : "image://theme/icon-m-play?") +
                         (pressed ? Theme.highlightColor : Theme.primaryColor)
            onClicked: playConf.value = !speechService.play
            anchors {
                right: parent.right
                rightMargin: Theme.paddingMedium
                bottom: parent.bottom
                bottomMargin: Theme.paddingMedium
            }
        }

        Label {
            visible: app.speechOff
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryHighlightColor
            wrapMode: Text.Wrap
            text: "<b>" + qsTr("No language is available.") + "</b> " +
                  qsTr("You can download Speech to Text, Text to Speech " +
                       "and Translator models for the languages you intend to use " +
                       "in the %1 app.").arg("<i>Speech Note</i>")
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }

            Label {
                id: inLabel

                anchors {
                    left: parent.left
                    right: parent.right
                }
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                wrapMode: Text.WordWrap
                opacity: text.length === 0 ? 0.0 : 1.0
                Behavior on opacity { FadeAnimator {} }
            }

            Label {
                id: outLabel

                anchors {
                    left: parent.left
                    right: parent.right
                }
                horizontalAlignment: Text.AlignHCenter
                color: Theme.primaryColor
                wrapMode: Text.WordWrap
                opacity: text.length === 0 ? 0.0 : 1.0
                Behavior on opacity { FadeAnimator {} }
            }

            Row {
                visible: speechService.play && app.appState === 7
                anchors.horizontalCenter: parent.horizontalCenter

                IconButton {
                    icon.source: "image://theme/icon-m-accept?" +
                                         (pressed ? Theme.highlightColor : Theme.primaryColor)
                    onClicked: {
                        if (app.appState === 7) {
                            console.log("confirm done")
                            app.appState = 8
                            speechService.init()
                        }
                    }
                }

                IconButton {
                    icon.source: "image://theme/icon-m-dismiss?" +
                                         (pressed ? Theme.highlightColor : Theme.primaryColor)
                    onClicked: {
                        if (app.appState === 7) {
                            console.log("reject done")
                            speechService.reset()
                            speechService.init()
                        }
                    }
                }
            }
        }

        Label {
            anchors {
                left: parent.left
                right: parent.right
                leftMargin: Theme.horizontalPageMargin
                rightMargin: Theme.horizontalPageMargin
                verticalCenter: parent.verticalCenter
            }
            horizontalAlignment: Text.AlignHCenter
            color: Theme.secondaryHighlightColor
            wrapMode: Text.WordWrap
            text: {
                if (app.speechStatus === 2) return speechService.translate_literal("decoding")
                if (app.speechStatus === 3) return speechService.translate_literal("initializing")
                return speechService.translate_literal("say_smth");
            }
            visible: app.speechInText.length === 0 && app.speechOutText.length === 0 &&
                     !app.speechOff && !speechService.busy && speechService.play
            opacity: text.length === 0 ? 0.0 : 1.0
            Behavior on opacity { FadeAnimator {} }
        }

        SpeechIndicator {
            anchors {
                bottom: parent.bottom
                bottomMargin: Theme.itemSizeLarge
                horizontalCenter: parent.horizontalCenter
            }
            width: Theme.itemSizeSmall
            color: Theme.highlightColor
            status: app.speechStatus
            off: app.speechOff
            visible: opacity > 0.0
            opacity: speechService.busy ? 0.0 : 1.0
            Behavior on opacity { FadeAnimator {} }
        }

        BusyIndicator {
            size: BusyIndicatorSize.Large
            anchors.centerIn: parent
            running: speechService.busy
        }
    }

    SpeechService {
        id: speechService

        property bool play: playConf.value
        property bool confirm: confirmConf.value
        property string inLang: ""
        property int inLangIdx: 0
        property var inLangList: []
        property string outLang: ""
        property int outLangIdx: 0
        property var outLangList: []

        onInLangIdxChanged: console.log("in lang idx changed:", inLangIdx)
        onOutLangIdxChanged: {console.log("out lang idx changed:", outLangIdx); outLangCombo.currentIndex = outLangIdx}

        onOutLangListChanged: setOutLangId(outLangConf.value)
        onInLangListChanged: setInLangId(inLangConf.value)

        function reset() {
            console.log("reset")
            app.appState = 0
            app.speechInText = ""
            app.speechOutText = ""
        }

        function init() {
            if (inLang.length === 0) {
                setInLangId(inLangConf.value)
                return
            }

            if (idle) {
                if (!play) return

                idleTimer.start()

                switch(app.appState) {
                case 0:
                    console.log("start listen")
                    startListen(inLang)
                    app.appState = 1
                    break
                case 1:
                    break
                case 2:
                    if (app.speechInText.length !== 0) {
                        if (inLang === outLang) {
                            app.speechOutText = app.speechInText
                            if (confirm) {
                                console.log("confirm wait")
                                app.appState = 7
                            } else {
                                console.log("playing")
                                playSpeech(app.speechInText, inLang)
                                app.appState = 5
                            }
                        } else {
                            console.log("translate")
                            translate(app.speechInText, inLang, outLang)
                            app.appState = 3
                        }
                    } else {
                        console.log("start listen")
                        startListen(inLang)
                        app.appState = 1
                    }
                    break
                case 3:
                    break
                case 4:
                    if (app.speechOutText.length !== 0) {
                        if (confirm) {
                            console.log("confirm wait")
                            app.appState = 7
                        } else {
                            console.log("playing")
                            playSpeech(app.speechOutText, outLang)
                            app.appState = 5
                        }
                        break
                    } else {
                        console.log("start listen")
                        startListen(inLang)
                        app.appState = 1
                    }
                    break
                case 5:
                    break
                case 6:
                    console.log("start listen")
                    startListen(inLang)
                    app.appState = 1
                    break
                case 7:
                    break
                case 8:
                    if (app.speechOutText.length !== 0) {
                        console.log("playing")
                        playSpeech(app.speechOutText, outLang)
                        app.appState = 5
                        break
                    } else {
                        console.log("start listen")
                        startListen(inLang)
                        app.appState = 1
                    }
                    break
                }
            }
        }

        function setInLangIdx(index) {
            var old_lang = inLang
            var old_idx = inLangIdx

            if (index >= 0 && index < inLangList.length) {
                var new_lang = inLangList[index][0]
                inLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                if (old_lang !== new_lang || old_idx !== index) {
                    console.log("in-lang changed: " + old_lang + " => " + new_lang)
                    inLang = new_lang
                    inLangIdx = index
                    fillOutLangs()
                }
            } else {
                console.log("failed to set new in-lang idx:", index)
            }
        }

        function setOutLangIdx(index) {
            var old_lang = outLang
            var old_idx = outLangIdx

            if (index >= 0 && index < outLangList.length) {
                var new_lang = outLangList[index][0]
                outLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                if (old_lang !== new_lang || old_idx !== index) {
                    console.log("out-lang changed: " + old_lang + " => " + new_lang)
                    outLang = new_lang
                    outLangIdx = index
                }
            } else {
                console.log("failed to set new out-lang idx:", index)
            }
        }

        function setInLangId(id) {
            var old_lang = inLang
            var new_lang = ""

            for (var i = 0; i < inLangList.length; i++) {
                if (inLangList[i][0] !== id) continue;
                new_lang = id
                inLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                console.log("in-lang changed: " + old_lang + " => " + new_lang)
                inLang = new_lang
                inLangIdx = i

                fillOutLangs()
                return
            }

            if (inLangList.length !== 0) {
                new_lang = inLangList[0][0]
                inLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                console.log("in-lang changed: " + old_lang + " => " + inLang)
                inLang = new_lang
                inLangIdx = 0

                fillOutLangs()
                return
            }

            console.log("failed to set new in-lang:", id)
        }

        function setOutLangId(id) {
            var old_lang = outLang
            var new_lang = ""

            for (var i = 0; i < outLangList.length; i++) {
                if (outLangList[i][0] !== id) continue;
                new_lang = id
                outLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                console.log("out-lang changed: " + old_lang + " => " + new_lang)
                outLang = new_lang
                outLangIdx = i
                return
            }

            if (outLangList.length !== 0) {
                new_lang = outLangList[0][0]
                outLangConf.value = new_lang
                if (old_lang !== new_lang)
                    reset()
                console.log("out-lang changed: " + old_lang + " => " + outLang)
                outLang = new_lang
                outLangIdx = 0
                return
            }

            console.log("failed to set new out-lang:", id)
        }

        function hasTts(id) {
            for (var ttsIdx = 0; ttsIdx < ttsLangList.length; ttsIdx++) {
                if (ttsLangList[ttsIdx][0] === id) {
                    return true
                }
            }
            return false
        }

        function hasMnt(id) {
            for (var mntIdx = 0; mntIdx < mntLangList.length; mntIdx++) {
                if (mntLangList[mntIdx][0] === id) {
                    return true
                }
            }
            return false
        }

        function idInList(id, list) {
            for (var idx = 0; idx < list.length; idx++) {
                if (id === list[idx][0]) return true
            }
            return false
        }

        function langListEqual(a, b) {
            if (a === b) return true
            if (a.length !== b.length) return false

            for (var i = 0; i < a.length; ++i)
                if (a[i][0] !== b[i][0]) return false

            return true
        }

        function updateLangs() {
            console.log("update langs")

            fillInLangs()
            fillOutLangs()
        }

        function fillInLangs() {
            var newInLangList = []
            for (var sttIdx = 0; sttIdx < sttLangList.length; sttIdx++) {
                var sttLangId = sttLangList[sttIdx][0];
                if (hasTts(sttLangId) || hasMnt(sttLangId)) {
                    newInLangList.push(sttLangList[sttIdx])
                }
            }

            if (!langListEqual(newInLangList, inLangList)) {
                inLangIdx = -1
                inLangList = newInLangList
            }
        }

        function fillOutLangs() {
            var ok = getOutLangsForTranslate(inLang, function(langs) {
                var newOutLangList = []
                for (var sttIdx = 0; sttIdx < sttLangList.length; sttIdx++) {
                    var sttLangId = sttLangList[sttIdx][0];
                    if (sttLangId === inLang && hasTts(sttLangId)) {
                        newOutLangList.push(sttLangList[sttIdx])
                    }
                }

                for (var id in langs) {
                    if (hasTts(id) && !idInList(id, newOutLangList)) {
                        newOutLangList.push([id, langs[id][1]])
                    }
                }

                if (!langListEqual(newOutLangList, outLangList)) {
                    outLangIdx = -1
                    outLangList = newOutLangList
                }
            })

            if (!ok) {
                console.log("fill out lang failed")

                fillOutLangsTimer.start()
            }
        }

        onPlayChanged: {
            reset()
            app.appState = 0

            if (play) init()
            else cancel()
        }

        active: true
        listeningMode: 0 /*Automatic*/

        onInLangChanged: {
            reset()
            app.appState = 0
            if (idle) init()
            else cancel()
        }

        onOutLangChanged: {
            reset()
            app.appState = 0
            if (idle) init()
            else cancel()
        }

        onSttLangListChanged: {
            updateLangs()
        }

        onTtsLangListChanged: {
            updateLangs()
        }

        onMntLangListChanged: {
            updateLangs()
        }

        onTextReady: {
            console.log("text ready")
            app.speechInText = text
            app.appState = 2
            cancel()
        }

        onTranslateFinished: {
            console.log("translate finished")
            app.speechOutText = outText
            app.appState = 4
        }

        onIntermediateTextReady: {
            if (text.length > 0)
                app.speechInText = text
        }

        onPlaySpeechFinished: {
            console.log("play speech finished")
            app.speechInText = ""
            app.speechOutText = ""
            app.appState = 6
        }

        onIdleChanged: {
            console.log("idle:", idle)
            if (idle) init()
        }

        onTaskEndedUnexpectedly: {
            console.log("task ended unexpectedly")
            reset()
            app.appState = 0
            if (idle) init()
            else cancel()
        }

        Timer {
            id: idleTimer

            repeat: false
            interval: 1000
            onTriggered: {
                if (speechService.idle && app.appState !== 7 && app.appState !== 8) {
                    console.log("idle timeout")
                    speechService.reset()
                    app.appState = 0
                    speechService.init()
                }
            }
        }

        Timer {
            id: fillOutLangsTimer

            repeat: false
            interval: 1000
            onTriggered: {
                console.log("fill out langs timeout")
                speechService.fillOutLangs()
            }
        }
    }
}
