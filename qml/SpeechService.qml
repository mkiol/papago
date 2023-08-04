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
    readonly property bool idle: dbus.state === 3 && !busy

    /*
    Speech status:
    0 = No Speech
    1 = Speech Detected
    2 = Speech Decoding/Encoding
    3 = Speech Initializing
    4 = Playing Speech
    */
    readonly property alias taskState: dbus.taskState

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
    readonly property bool busy: taskState !== 2 && taskState !== 3 && (dbus.state === 2 || anotherAppConnected)

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
    MntLangs: map [lang_id] => [mnt_model_id, lang_name]
        list of langs for translation from
    */
    readonly property alias mntLangs: dbus.mntLangs

    /*
    MntLangList: list [lang_id, lang_name]
        list of langs for translation from
    */
    readonly property alias mntLangList: dbus.mntLangList

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
    TranslateFinished: Translation finished
    */
    signal translateFinished(string outText, string outLang)

    /*
    TaskEndedUnexpectedly: Task was ended from service side
    */
    signal taskEndedUnexpectedly()

    /*
    Cancel: cancels any task
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
                           dbus.updateStateProperties()
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
                           dbus.updateStateProperties()
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
                  [{"type": "i", "value": root.listeningMode}, {"type": "s", "value": lang}, {"type": "s", "value": ""}],
                  function(result) {
                      dbus.myTask = result
                      dbus.updateStateProperties()
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
                      dbus.updateStateProperties()
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
    function stopSpeech() {
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
                      dbus.updateStateProperties()
                      if (result !== 0) {
                          console.error("stopSpeech failed")
                      }
                  }, _handle_error)
    }

    /*
    Translate: translate text
    */
    function translate(text, lang, outLang) {
        if (busy) {
            console.error("cannot call translate, speech service is busy")
            return;
        }

        dbus.typedCall("MntTranslate",
                  [{"type": "s", "value": text}, {"type": "s", "value": lang},
                   {"type": "s", "value": outLang}],
                  function(result) {
                      dbus.myTask = result
                      dbus.updateStateProperties()
                      if (result < 0) {
                          console.error("translate failed")
                      } else {
                          _keepAliveTask()
                      }
                  }, _handle_error)
    }

    /*
    GetOutLangsForTranslate: return supported languages to translate into
    */
    function getOutLangsForTranslate(lang, callback) {
        if (busy) {
            console.error("cannot call getOutLangsForTranslate, speech service is busy")
            return;
        }

        dbus.typedCall("MntGetOutLangs",
                  [{"type": "s", "value": lang}],
                  function(result) {
                      callback(result)
                  }, _handle_error)
    }

    // private API
    function translate_literal(id) {
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
                           } else {
                               console.log("service task ended unexpectedly")
                               root.taskEndedUnexpectedly()
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
        dbus.updateStateProperties()
    }

    function _handle_error(error, message) {
        console.debug("DBus call failed", error, "message:", message)
        dbus.updateStateProperties()
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
        9 = Writing speech to file
        10 = Translating
        */
        property int state: 0

        /*
        Task states:
        0 = No Speech
        1 = Speech Detected
        2 = Speech Decoding/Encoding
        3 = Speech Initializing
        4 = Playing Speech
        */
        property int taskState: 0

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
        MntLangs: map [lang_id] => [mnt_model_id, lang_name]
            list of langs for translation from
        */
        property var mntLangs

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

        /*
        MntLangList: list [lang_id, lang_name]
            list of langs for translation from
        */
        property var mntLangList

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

        function mntTranslateFinished(inText, inLang, outText, outLang, task) {
            if (myTask === task) {
                root.translateFinished(outText, outLang)
            }
        }

        function statePropertyChanged(state) {
            console.log("state changed:", state)
            dbus.state = state
        }

        function taskStatePropertyChanged(taskState) {
            console.log("task state chaged:", taskState)
            if (dbus.currentTask === dbus.myTask) {
                dbus.taskState = taskState
            }
        }

        function currentTaskPropertyChanged(task) {
            console.log("current task changed:", task)
            dbus.currentTask = task
            if (dbus.currentTask == -1) dbus.myTask = -1
            if (dbus.currentTask > -1 && dbus.currentTask === dbus.myTask) {
                dbus.taskState = dbus.getProperty("TaskState")
            } else {
                dbus.taskState = 0
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

        function mntLangsPropertyChanged(langs) {
            dbus.mntLangs = langs
        }

        function mntLangListPropertyChanged(langs) {
            dbus.mntLangList = langs
        }

        function updateProperties() {
            updateStateProperties()

            dbus.translations = dbus.getProperty("Translations")
            dbus.sttLangs = dbus.getProperty("SttLangs")
            dbus.ttsLangs = dbus.getProperty("TtsLangs")
            dbus.sttLangList = dbus.getProperty("SttLangList")
            dbus.ttsLangList = dbus.getProperty("TtsLangList")
            dbus.sttTtsLangList = dbus.getProperty("SttTtsLangList")
            dbus.mntLangs= dbus.getProperty("MntLangs")
            dbus.mntLangList= dbus.getProperty("MntLangList")

            if (dbus.state === 0 || dbus.state === 2 ||
                    dbus.sttLangList.length === 0 ||
                    dbus.ttsLangList.length === 0) busyTimer.start()
        }

        function updateStateProperties() {
            dbus.currentTask = dbus.getProperty("CurrentTask")
            if (dbus.currentTask == -1) dbus.myTask = -1
            dbus.state = dbus.getProperty("State")
            if (dbus.currentTask > -1 && dbus.currentTask === dbus.myTask) {
                dbus.taskState = dbus.getProperty("TaskState")
            } else {
                dbus.taskState = 0
            }
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

    Timer {
        id: busyTimer
        repeat: false
        interval: 5000
        onTriggered: dbus.updateProperties()
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
