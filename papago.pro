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

TRANSLATIONS += translations/$${TARGET}-pl.ts
