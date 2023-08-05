TARGET = harbour-papago

CONFIG += sailfishapp_qml

DISTFILES += \
    qml/$${TARGET}.qml \
    qml/SpeechIndicator.qml \
    qml/SpeechService.qml \
    rpm/papago.spec \
    translations/*.ts \
    $${TARGET}.desktop

SAILFISHAPP_ICONS = 86x86 108x108 128x128 172x172

CONFIG += sailfishapp_i18n

TRANSLATIONS += translations/$${TARGET}-cs.ts \
                translations/$${TARGET}-de.ts \
                translations/$${TARGET}-es.ts \
                translations/$${TARGET}-et.ts \
                translations/$${TARGET}-el.ts \
                translations/$${TARGET}-fr.ts \
                translations/$${TARGET}-fi.ts \
                translations/$${TARGET}-hu.ts \
                translations/$${TARGET}-nl.ts \
                translations/$${TARGET}-it.ts \
                translations/$${TARGET}-pl.ts \
                translations/$${TARGET}-pt.ts \
                translations/$${TARGET}-sv.ts \
                translations/$${TARGET}-sl.ts \
                translations/$${TARGET}-sk.ts \
                translations/$${TARGET}-ro.ts \
                translations/$${TARGET}-ru.ts \
                translations/$${TARGET}-uk.ts \
                translations/$${TARGET}-zh.ts
