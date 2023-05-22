/* Copyright (C) 2021-2023 Michal Kosciesza <michal@mkiol.net>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */

import QtQuick 2.0
import Nemo.DBus 2.0

Item {
    id: root

    /*
    Active:
        set 'true' to send keepalive pings to Speech service to stop
        the service shutdown
        when app is in background 'active' should be set to 'false' to
        release resources
    */
    property bool active: false

    /*
    ListeningMode:
    0 = Automatic
    1 = Manual
    2 = One Sentence
    */
    property int listeningMode: 2

    /*
    Connected: connected to Speech service
    */
    readonly property bool connected: dbus.state > 0

    /*
    Idle: speech service is idle and ready to receive task request
    */
    readonly property bool idle: dbus.state === 3

    /*
    Speech status:
    0 = No Speech
    1 = Speech Detected
    2 = Speech Decoding/Encoding
    3 = Speech Initializing
    4 = Playing Speech
    */
    readonly property alias speech: dbus.speech

    /*
    Listening: microphone is in use
    */
    readonly property bool listening: dbus.state > 3 && dbus.state < 8 && !anotherAppConnected

    /*
    Playing: speech service plays audio
    */
    readonly property bool playing: dbus.state === 8 && !anotherAppConnected

    /*
    AnotherAppConnected: another app is using Speech service
    */
    readonly property bool anotherAppConnected: dbus.myTask !== dbus.currentTask

    /*
    Busy: speech service is busy
    */
    readonly property bool busy: speech !== 2 && speech !== 3 && (dbus.state === 2 || anotherAppConnected)

    /*
    SttLangs: map [lang_id] => [stt_model_id, stt_model_name]
        map of langs with support for STT
    */
    readonly property alias sttLangs: dbus.sttLangs

    /*
    TtsLangs: map [lang_id] => [tts_model_id, tts_model_name]
        map of langs with support for TTS
    */
    readonly property alias ttsLangs: dbus.ttsLangs

    /*
    SttLangList: list [lang_id, lang_name]
        list of langs with support for STT
    */
    readonly property alias sttLangList: dbus.sttLangList

    /*
    TtsLangList: list [lang_id, lang_name]
        list of langs with support for TTS
    */
    readonly property alias ttsLangList: dbus.ttsLangList

    /*
    SttTtsLangList: list [lang_id, lang_name]
        list of langs with support for both STT and TTS
    */
    readonly property alias sttTtsLangList: dbus.sttTtsLangList

    /*
    Configured: speech service has at least one language model configured
    */
    readonly property bool configured: dbus.state > 1

    /*
    IntermediateTextReady: partial STT result
    */
    signal intermediateTextReady(string text)

    /*
    TextReady: final STT result
    */
    signal textReady(string text)

    /*
    PartialSpeechPlaying: partial TTS playback started
    */
    signal partialSpeechPlaying(string text)

    /*
    PlaySpeechFinished: TTS playback finished
    */
    signal playSpeechFinished()

    /*
    Cancel: cancels any STT or TTS task
    */
    function cancel() {
        if (busy) {
            console.warn("cannot call cancel, speech service is busy")
            return;
        }

        if (dbus.myTask < 0) {
            console.warn("cannot call cancel, no active task")
            return;
        }

        keepaliveTaskTimer.stop()
        dbus.typedCall("Cancel", [{"type": "i", "value": dbus.myTask}],
                       function(result) {
                           if (result !== 0) {
                               console.error("cancel failed")
                           }
                       }, _handle_error)
    }

    /*
    StopListen: stops STT task
    */
    function stopListen() {
        if (busy) {
            console.warn("cannot call stopListen, speech service is busy")
            return;
        }

        if (dbus.myTask < 0) {
            console.warn("cannot call stopListen, no active task")
            return;
        }

        keepaliveTaskTimer.stop()
        dbus.typedCall("SttStopListen", [{"type": "i", "value": dbus.myTask}],
                       function(result) {
                           if (result !== 0) {
                               console.error("stopListen failed")
                           }
                       }, _handle_error)
    }

    /*
    StartListen: starts STT task
    */
    function startListen(lang) {
        if (busy) {
            console.error("cannot call startListen, speech service is busy")
            return;
        }

        if (!lang) lang = '';

        dbus.typedCall("SttStartListen",
                  [{"type": "i", "value": root.listeningMode}, {"type": "s", "value": lang}, {"type": "b", "value": false}],
                  function(result) {
                      dbus.myTask = result
                      if (result < 0) {
                          console.error("startListen failed")
                      } else {
                          _keepAliveTask()
                      }
                  }, _handle_error)
    }

    /*
    PlaySpeech: starts TTS task
    */
    function playSpeech(text, lang) {
        if (busy) {
            console.error("cannot call playListen, speech service is busy")
            return;
        }

        if (!lang) lang = '';

        dbus.typedCall("TtsPlaySpeech",
                  [{"type": "s", "value": text}, {"type": "s", "value": lang}],
                  function(result) {
                      dbus.myTask = result
                      if (result < 0) {
                          console.error("playSpeech failed")
                      } else {
                          _keepAliveTask()
                      }
                  }, _handle_error)
    }

    /*
    StopSpeech: stops TTS task
    */
    function stopSpeech(text, lang) {
        if (busy) {
            console.error("cannot call stopSpeech, speech service is busy")
            return;
        }

        if (dbus.myTask < 0) {
            console.warn("cannot call stopSpeech, no active task")
            return;
        }

        dbus.typedCall("TtsStopSpeech",
                  [{"type": "i", "value": dbus.myTask}],
                  function(result) {
                      dbus.myTask = result
                      if (result < 0) {
                          console.error("stopSpeech failed")
                      } else {
                          _keepAliveTask()
                      }
                  }, _handle_error)
    }

    // private API
    function translate(id) {
        if (connected) {
            var trans = dbus.translations[id]
            if (trans.length > 0) return trans
        }
        return ""
    }

    // ------

    function _keepAliveTask() {
        if (dbus.myTask < 0) return;
        dbus.typedCall("KeepAliveTask", [{"type": "i", "value": dbus.myTask}],
                       function(result) {
                           if (result > 0 && root.active && dbus.myTask > -1) {
                               keepaliveTaskTimer.interval = result * 0.75
                               keepaliveTaskTimer.start()
                           }
                       }, _handle_error)
    }

    function _keepAliveService() {
        dbus.typedCall("KeepAliveService", [],
                       function(result) {
                           if (result > 0 && root.active) {
                               keepaliveServiceTimer.interval = result * 0.75
                               keepaliveServiceTimer.start()
                           }
                       }, _handle_error)
    }

    function _handle_result(result) {
        console.debug("DBus call completed", result)
    }

    function _handle_error(error, message) {
        console.debug("DBus call failed", error, "message:", message)
    }

    DBusInterface {
        id: dbus

        /*
        States:
        0 = Unknown
        1 = Not Configured
        2 = Busy
        3 = Idle
        4 = Listening Manual
        5 = Listening Auto
        6 = Transcribing File
        7 = Listening One-sentence
        8 = Playing speech
        */
        property int state: 0

        /*
        Speech:
        0 = No Speech
        1 = Speech Detected
        2 = Speech Decoding/Encoding
        3 = Speech Initializing
        4 = Playing Speech
        */
        property int speech: 0

        /*
        SttLangs: map [lang_id] => [stt_model_id, stt_model_name]
            map of langs with support for STT
        */
        property var sttLangs

        /*
        TtsLangs: map [lang_id] => [tts_model_id, tts_model_name]
            map of langs with support for TTS
        */
        property var ttsLangs

        /*
        SttLangList: list [lang_id, lang_name]
            list of langs with support for STT
        */
        property var sttLangList

        /*
        TtsLangList: list [lang_id, lang_name]
            list of langs with support for TTS
        */
        property var ttsLangList

        /*
        SttTtsLangList: list [lang_id, lang_name]
            list of langs with support for both STT and TTS
        */
        property var sttTtsLangList

        property int myTask: -1
        property int currentTask: -1

        // private API
        property var translations: []

        service: "org.mkiol.Speech"
        iface: "org.mkiol.Speech"
        path: "/"

        signalsEnabled: true

        function sttIntermediateTextDecoded(text, lang, task) {
            if (myTask === task) {
                root.intermediateTextReady(text)
            }
        }

        function sttTextDecoded(text, lang, task) {
            if (myTask === task) {
                root.textReady(text)
            }
        }

        function ttsPlaySpeechFinished(task) {
            if (myTask === task) {
                root.playSpeechFinished()
            }
        }

        function ttsPartialSpeechPlaying(text, task) {
            if (myTask === task) {
                root.partialSpeechPlaying(text)
            }
        }

        function statePropertyChanged(state) {
            dbus.state = state
        }

        function speechPropertyChanged(speech) {
            if (dbus.currentTask === dbus.myTask) {
                dbus.speech = speech
            }
        }

        function currentTaskPropertyChanged(task) {
            dbus.currentTask = task
            if (dbus.currentTask == -1) dbus.myTask = -1
            if (dbus.currentTask > -1 && dbus.currentTask === dbus.myTask) {
                dbus.speech = dbus.getProperty("Speech")
            } else {
                dbus.speech = 0
            }
        }

        function sttLangsPropertyChanged(langs) {
            dbus.sttLangs = langs
        }

        function ttsLangsPropertyChanged(langs) {
            dbus.ttsLangs = langs
        }

        function sttLangListPropertyChanged(langs) {
            dbus.sttLangList = langs
        }

        function ttsLangListPropertyChanged(langs) {
            dbus.ttsLangList = langs
        }

        function sttTtsLangListPropertyChanged(langs) {
            dbus.sttTtsLangList = langs
        }

        function updateProperties() {
            dbus.translations = dbus.getProperty("Translations")
            dbus.currentTask = dbus.getProperty("CurrentTask")
            if (dbus.currentTask == -1) dbus.myTask = -1
            dbus.state = dbus.getProperty("State")
            if (dbus.currentTask > -1 && dbus.currentTask === dbus.myTask) {
                dbus.speech = dbus.getProperty("Speech")
            } else {
                dbus.speech = 0
            }
            dbus.sttLangs = dbus.getProperty("SttLangs")
            dbus.ttsLangs = dbus.getProperty("TtsLangs")
            dbus.sttLangList = dbus.getProperty("SttLangList")
            dbus.ttsLangList = dbus.getProperty("TtsLangList")
            dbus.sttTtsLangList = dbus.getProperty("SttTtsLangList")
        }
    }

    Timer {
        id: keepaliveServiceTimer
        repeat: false
        onTriggered: _keepAliveService()
    }

    Timer {
        id: keepaliveTaskTimer
        repeat: false
        onTriggered: _keepAliveTask()
    }

    onActiveChanged: {
        if (active) {
            _keepAliveService()
            dbus.updateProperties()
        } else {
            keepaliveServiceTimer.stop()
            cancel()
        }
    }

    Component.onCompleted: {
        if (active) dbus.updateProperties()
    }

    Component.onDestruction: {
        cancel()
    }
}
