import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.modules.utils
import qs.modules.customComponents
import qs.modules.settings

Item {
    id: root
    anchors.fill: parent
    focus: true

    signal closed

    // ── Word bank ──────────────────────────────────────────────────
    readonly property var wordBank: [
        "the","be","to","of","and","a","in","that","have","it","for","not","on","with",
        "he","as","you","do","at","this","but","his","by","from","they","we","say","her",
        "she","or","an","will","my","one","all","would","there","their","what","so","up",
        "out","if","about","who","get","which","go","me","when","make","can","like","time",
        "no","just","him","know","take","people","into","year","your","good","some","could",
        "them","see","other","than","then","now","look","only","come","its","over","think",
        "also","back","after","use","two","how","our","work","first","well","way","even",
        "new","want","because","any","these","give","day","most","us","great","between",
        "large","often","hand","high","place","hold","turn","move","live","where","much",
        "help","through","line","right","too","mean","old","same","tell","follow","came",
        "show","form","small","set","put","end","does","another","need","big","point",
        "play","number","off","always","learn","plant","cover","food","sun","four","state",
        "keep","eye","never","last","let","thought","city","tree","cross","farm","hard",
        "start","might","story","saw","far","sea","draw","left","late","run","while",
        "press","close","night","real","life","few","north","open","seem","together","next",
        "white","children","begin","got","walk","paper","group","music","those","both","mark",
        "book","letter","mile","river","car","feet","care","second","plain","girl","young",
        "ready","above","ever","red","list","feel","talk","bird","soon","body","dog","family"
    ]

    // ── State ──────────────────────────────────────────────────────
    property int  timeLimit:     30
    property int  timeLeft:      30
    property bool running:       false
    property bool finished:      false

    property var    words:          []
    property var    charStates:     []   // parallel: list of list of "pending"|"correct"|"wrong"
    property int    currentWordIdx: 0
    property string typedWord:      ""

    property int correctChars: 0
    property int totalChars:   0
    property int wpm:          0
    property int accuracy:     100

    // word area row sizing
    readonly property int wordFontSize: 20
    readonly property int rowH:         wordFontSize + 20   // 40px per row
    readonly property int rowSpacing:   12                  // between rows
    readonly property int rowStep:      rowH + rowSpacing   // 52px per row step

    // ── Helpers ────────────────────────────────────────────────────
    function generateWords() {
        const pool = []
        while (pool.length < 80)
            pool.push(...wordBank.slice().sort(() => Math.random() - 0.5))
        words      = pool.slice(0, 80)
        charStates = words.map(w => Array(w.length).fill("pending"))
    }

    function restart() {
        timeLeft       = timeLimit
        running        = false
        finished       = false
        correctChars   = 0
        totalChars     = 0
        wpm            = 0
        accuracy       = 100
        currentWordIdx = 0
        typedWord      = ""
        timer.stop()
        generateWords()
        flick.contentY = 0
        root.forceActiveFocus()
    }

    function computeStats() {
        const elapsed = timeLimit - timeLeft
        if (elapsed <= 0) return
        wpm      = Math.round((correctChars / 5) / (elapsed / 60))
        accuracy = totalChars > 0 ? Math.round(correctChars / totalChars * 100) : 100
    }

    function finish() {
        timer.stop()
        running  = false
        finished = true
        computeStats()
    }

    function updateLive(typed) {
        const word   = words[currentWordIdx] || ""
        const states = []
        for (let i = 0; i < word.length; i++)
            states.push(i >= typed.length ? "pending" : typed[i] === word[i] ? "correct" : "wrong")
        const next = [...charStates]
        next[currentWordIdx] = states
        charStates = next
    }

    function commitWord(typed) {
        const word = words[currentWordIdx]
        for (let i = 0; i < Math.max(typed.length, word.length); i++) {
            if (i < word.length) {
                totalChars++
                if (i < typed.length && typed[i] === word[i]) correctChars++
            }
        }
        // Count the space as a character (matches MonkeyType's WPM definition)
        totalChars++
        correctChars++

        const states = []
        for (let i = 0; i < word.length; i++)
            states.push(i >= typed.length ? "pending" : typed[i] === word[i] ? "correct" : "wrong")
        const next = [...charStates]
        next[currentWordIdx] = states
        charStates = next
        currentWordIdx++
    }

    function handleChar(ch) {
        if (finished) return
        if (!running) { running = true; timer.start() }
        typedWord += ch
        updateLive(typedWord)
    }

    function handleSpace() {
        if (finished || typedWord.length === 0) return
        if (!running) { running = true; timer.start() }
        commitWord(typedWord)
        typedWord = ""
        if (currentWordIdx >= words.length) { finish(); return }
        computeStats()
        Qt.callLater(scrollToCurrent)
    }

    function handleBackspace() {
        if (finished || typedWord.length === 0) return
        typedWord = typedWord.slice(0, -1)
        updateLive(typedWord)
    }

    function scrollToCurrent() {
        const item = wordRepeater.itemAt(currentWordIdx)
        if (!item) return
        // item.y is position within the Flow
        const currentRow = Math.floor(item.y / rowStep)
        // keep current row as 2nd visible row (0-indexed: row 1)
        const targetY = Math.max(0, (currentRow - 1) * rowStep)
        if (Math.abs(flick.contentY - targetY) > 4) {
            scrollAnim.to = targetY
            scrollAnim.restart()
        }
    }

    Component.onCompleted: {
        generateWords()
        root.forceActiveFocus()
    }

    // ── Timer ──────────────────────────────────────────────────────
    Timer {
        id: timer; interval: 1000; repeat: true
        onTriggered: { root.timeLeft--; root.computeStats(); if (root.timeLeft <= 0) root.finish() }
    }

    NumberAnimation {
        id: scrollAnim; target: flick; property: "contentY"
        duration: 200; easing.type: Easing.OutQuad
    }

    // ── Focus / input ──────────────────────────────────────────────
    MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }

    Keys.onPressed: function(event) {
        switch (event.key) {
            case Qt.Key_Escape:    root.closed();    event.accepted = true; break
            case Qt.Key_Tab:       root.restart();   event.accepted = true; break
            case Qt.Key_Space:     root.handleSpace(); event.accepted = true; break
            case Qt.Key_Backspace: root.handleBackspace(); event.accepted = true; break
            default:
                if (event.text.length === 1) {
                    root.handleChar(event.text)
                    event.accepted = true
                }
        }
    }

    // ── Root layout ────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin:  36
        anchors.rightMargin: 36
        anchors.topMargin:   24
        anchors.bottomMargin: 24
        spacing: 0

        // ── Top bar ───────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 8

            // Mode chips
            Repeater {
                model: [15, 30, 60]
                delegate: Rectangle {
                    required property int modelData
                    required property int index
                    Layout.preferredWidth:  42
                    Layout.preferredHeight: 26
                    radius: 13
                    color: root.timeLimit === modelData
                        ? Colors.primary
                        : modeHover.containsMouse
                            ? Qt.alpha(Colors.primary, 0.14)
                            : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    CustomText {
                        anchors.centerIn: parent
                        content: modelData + "s"; size: 12; weight: 700
                        customColor: root.timeLimit === modelData ? Colors.primaryText : Colors.outline
                    }
                    MouseArea {
                        id: modeHover; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.timeLimit = modelData; root.restart() }
                    }
                }
            }

            // Thin divider
            Rectangle {
                Layout.preferredWidth: 1; Layout.preferredHeight: 16
                color: Qt.alpha(Colors.outline, 0.3)
            }

            // Live accuracy during run
            CustomText {
                visible: root.running && !root.finished
                content: root.accuracy + "%"
                size: 12; weight: 600
                customColor: Colors.outline
            }

            Item { Layout.fillWidth: true }

            // Countdown
            CustomText {
                content: root.finished ? "—" : root.timeLeft + ""
                size: 22; weight: 700
                customColor: (root.timeLeft <= 5 && root.running && !root.finished)
                    ? Colors.error : Colors.primary
                Behavior on customColor { ColorAnimation { duration: 200 } }
            }

            // Close
            MaterialIconSymbol {
                content: "close"; iconSize: 18
                color: Qt.alpha(Colors.outline, 0.6)
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.closed()
                }
            }
        }

        // ── Thin separator ────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 1
            Layout.topMargin: 16; Layout.bottomMargin: 20
            color: Qt.alpha(Colors.outline, 0.15)
        }

        // ── Results screen ────────────────────────────────────────
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.finished

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 48

                    Repeater {
                        model: [
                            { v: root.wpm,      suffix: "",  label: "wpm", col: Colors.primary   },
                            { v: root.accuracy,  suffix: "%", label: "acc", col: Colors.secondary  },
                            { v: root.timeLimit, suffix: "s", label: "time", col: Colors.tertiary  }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            spacing: 2
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: modelData.v + modelData.suffix
                                size: 56; weight: 700
                                customColor: modelData.col
                            }
                            CustomText {
                                Layout.alignment: Qt.AlignHCenter
                                content: modelData.label
                                size: 12; weight: 600; customColor: Colors.outline
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 24
                    Layout.preferredHeight: 40
                    Layout.preferredWidth: retryRow.implicitWidth + 32
                    radius: 20
                    color: retryHover.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.12)
                    Behavior on color { ColorAnimation { duration: 130 } }

                    RowLayout {
                        id: retryRow; anchors.centerIn: parent; spacing: 8
                        MaterialIconSymbol {
                            content: "refresh"; iconSize: 17
                            color: retryHover.containsMouse ? Colors.primaryText : Colors.primary
                        }
                        CustomText {
                            content: "Try again"; size: 13; weight: 700
                            customColor: retryHover.containsMouse ? Colors.primaryText : Colors.primary
                        }
                    }
                    MouseArea {
                        id: retryHover; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.restart()
                    }
                }

                CustomText {
                    Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 12
                    content: "tab  —  restart   ·   esc  —  close"
                    size: 10; weight: 500
                    customColor: Qt.alpha(Colors.outline, 0.4)
                }
            }
        }

        // Spacer — pushes word area toward vertical center
        Item { Layout.fillHeight: true; visible: !root.finished }

        // ── Word area — exactly 3 rows visible ────────────────────
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.rowStep * 3
            visible: !root.finished
            clip: true

            Flickable {
                id: flick
                anchors.fill: parent
                contentWidth:  width
                contentHeight: flow.implicitHeight
                interactive:   false
                clip:          true

                Flow {
                    id: flow
                    width:   flick.width
                    spacing: root.rowSpacing

                    Repeater {
                        id: wordRepeater
                        model: root.words

                        delegate: Item {
                            id: fw
                            required property string modelData
                            required property int    index

                            property bool isCurrent: index === root.currentWordIdx
                            property bool isDone:    index  < root.currentWordIdx
                            property var  states:    root.charStates.length > index
                                                        ? root.charStates[index] : []

                            implicitWidth:  wordChars.implicitWidth
                            implicitHeight: root.rowH

                            // Subtle underline on current word
                            Rectangle {
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                x: 0; width: wordChars.implicitWidth; height: 2; radius: 1
                                color: Colors.primary
                                opacity: fw.isCurrent ? 0.5 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Row {
                                id: wordChars
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Repeater {
                                    model: fw.modelData.length
                                    delegate: Item {
                                        required property int index
                                        property string ch: fw.modelData[index]
                                        property string st: fw.states.length > index
                                                            ? fw.states[index] : "pending"
                                        property bool cursorHere: fw.isCurrent
                                                                && index === root.typedWord.length

                                        width:  letter.implicitWidth
                                        height: letter.implicitHeight

                                        // Blinking caret before this char
                                        Rectangle {
                                            x: 0
                                            anchors.top: parent.top; anchors.topMargin: 2
                                            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                                            width: 2; radius: 1; color: Colors.primary
                                            visible: cursorHere
                                            SequentialAnimation on opacity {
                                                running: cursorHere && root.running
                                                loops:   Animation.Infinite
                                                NumberAnimation { to: 0; duration: 530 }
                                                NumberAnimation { to: 1; duration: 100 }
                                            }
                                        }

                                        Text {
                                            id: letter
                                            text: parent.ch
                                            font.pixelSize: root.wordFontSize
                                            font.family:    SettingsConfig.general.defaultFont
                                            font.weight:    Font.Normal
                                            color: {
                                                if (!fw.isDone && !fw.isCurrent)
                                                    return Qt.alpha(Colors.surfaceText, 0.22)
                                                switch (parent.st) {
                                                    case "correct": return Colors.primary
                                                    case "wrong":   return Colors.error
                                                    default:        return Qt.alpha(Colors.surfaceText, 0.4)
                                                }
                                            }
                                            Behavior on color { ColorAnimation { duration: 60 } }
                                        }
                                    }
                                }

                                // Overflow chars typed past word length
                                Repeater {
                                    model: fw.isCurrent
                                        ? Math.max(0, root.typedWord.length - fw.modelData.length)
                                        : 0
                                    delegate: Text {
                                        required property int index
                                        text: {
                                            const i = fw.modelData.length + index
                                            return i < root.typedWord.length ? root.typedWord[i] : ""
                                        }
                                        font.pixelSize: root.wordFontSize
                                        font.family:    SettingsConfig.general.defaultFont
                                        font.weight:    Font.Normal
                                        color: Colors.error
                                    }
                                }

                                // End-of-word caret (cursor after last char)
                                Rectangle {
                                    width: 2; height: root.wordFontSize; radius: 1
                                    color: Colors.primary
                                    visible: fw.isCurrent && root.typedWord.length >= fw.modelData.length
                                    SequentialAnimation on opacity {
                                        running: visible && root.running
                                        loops:   Animation.Infinite
                                        NumberAnimation { to: 0; duration: 530 }
                                        NumberAnimation { to: 1; duration: 100 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; visible: !root.finished }

        // ── Hint / live stats bar ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true; Layout.bottomMargin: 4
            spacing: 16

            CustomText {
                content: "tab  —  restart"
                size: 10; weight: 500
                customColor: Qt.alpha(Colors.outline, 0.4)
            }
            CustomText {
                content: "esc  —  close"
                size: 10; weight: 500
                customColor: Qt.alpha(Colors.outline, 0.4)
            }

            Item { Layout.fillWidth: true }

            CustomText {
                visible: !root.finished
                content: root.running
                    ? root.wpm + " wpm"
                    : "start typing…"
                size: 12; weight: 600
                customColor: root.running ? Colors.outline : Qt.alpha(Colors.outline, 0.45)
            }
        }
    }
}
