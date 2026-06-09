pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.settings

Singleton {
    id: root

    property string backend: SettingsConfig.ai.backend ?? "gemini"

    property bool isLoading: false
    property bool isStreaming: false
    property bool hasError: false
    property string errorMessage: ""
    property string streamingText: ""
    property var chatHistory: []

    readonly property string apiKey: SettingsConfig.ai.googleApiKey
    readonly property string geminiModel: "gemini-2.0-flash"
    readonly property string geminiUrl: "https://generativelanguage.googleapis.com/v1beta/models/" + geminiModel + ":generateContent"

    readonly property string ollamaModel: SettingsConfig.ai.ollamaModel ?? "llama3.2"
    readonly property string ollamaUrl: "http://localhost:11434/api/chat"


    readonly property string currentModel: backend === "gemini" ? geminiModel : ollamaModel


    // only used for gemini typing animation
    property string _fullResponse: ""
    property int _streamIdx: 0

    // ollama accumulates here
    property string _ollamaAccumulated: ""

    Timer {
        id: typeTimer
        interval: 12
        repeat: true
        onTriggered: {
            let end = Math.min(root._streamIdx + 4, root._fullResponse.length)
            root.streamingText = root._fullResponse.substring(0, end)
            root._streamIdx = end
            if (end >= root._fullResponse.length) {
                typeTimer.stop()
                root.isStreaming = false
                root.chatHistory = [...root.chatHistory, { role: "model", text: root._fullResponse }]
                root.streamingText = ""
                root._streamIdx = 0
                root._fullResponse = ""
            }
        }
    }

    function sendMessage(userMessage) {
        if (isLoading || isStreaming || userMessage.trim() === "") return

        root.isLoading = true
        root.hasError = false
        root.errorMessage = ""
        root.chatHistory = [...root.chatHistory, { role: "user", text: userMessage }]

        if (root.backend === "ollama") {
            _sendOllama()
        } else {
            _sendGemini()
        }
    }

    function _sendGemini() {
        if (apiKey === "") {
            root.hasError = true
            root.errorMessage = "No API key set. Add your Google AI key in Settings → AI."
            root.isLoading = false
            root.chatHistory = root.chatHistory.slice(0, -1)
            return
        }

        let contents = root.chatHistory.map(msg => ({
            role: msg.role === "model" ? "model" : "user",
            parts: [{ text: msg.text }]
        }))

        let bodyStr = JSON.stringify({ contents: contents })
        let escapedBody = bodyStr.replace(/'/g, "'\\''")
        let cmd = "printf '%s' '" + escapedBody + "' | curl -s -X POST '" + root.geminiUrl + "' -H 'Content-Type: application/json' -H 'x-goog-api-key: " + root.apiKey + "' -d @-"
        geminiProcess.command[2] = cmd
        geminiProcess.running = true
    }

    function _sendOllama() {
        root._ollamaAccumulated = ""
        root.streamingText = ""

        let messages = root.chatHistory.map(msg => ({
            role: msg.role === "model" ? "assistant" : "user",
            content: msg.text
        }))

        let bodyStr = JSON.stringify({
            model: root.ollamaModel,
            messages: messages,
            stream: true
        })

        let escapedBody = bodyStr.replace(/'/g, "'\\''")
        let cmd = "printf '%s' '" + escapedBody + "' | curl -s -X POST '" + root.ollamaUrl + "' -H 'Content-Type: application/json' -d @-"
        ollamaProcess.command[2] = cmd
        ollamaProcess.running = true
    }

    function clearHistory() {
        typeTimer.stop()
        root.chatHistory = []
        root.hasError = false
        root.errorMessage = ""
        root.streamingText = ""
        root.isStreaming = false
        root.isLoading = false
        root._streamIdx = 0
        root._fullResponse = ""
        root._ollamaAccumulated = ""
    }

    // --- Gemini process (unchanged, uses StdioCollector) ---
    Process {
        id: geminiProcess
        command: ["bash", "-c", ""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.isLoading = false
                if (text.length === 0) {
                    root.hasError = true
                    root.errorMessage = "Empty response from Gemini."
                    root.chatHistory = root.chatHistory.slice(0, -1)
                    return
                }
                try {
                    const data = JSON.parse(text)
                    if (data.error) {
                        root.hasError = true
                        root.errorMessage = data.error.message || "API error"
                        root.chatHistory = root.chatHistory.slice(0, -1)
                        return
                    }
                    if (data.candidates?.length > 0) {
                        root._fullResponse = data.candidates[0].content.parts[0].text
                        root._streamIdx = 0
                        root.streamingText = ""
                        root.isStreaming = true
                        typeTimer.start()
                    } else {
                        root.hasError = true
                        root.errorMessage = "No response candidates returned."
                        root.chatHistory = root.chatHistory.slice(0, -1)
                    }
                } catch (e) {
                    root.hasError = true
                    root.errorMessage = "Failed to parse Gemini response."
                    root.chatHistory = root.chatHistory.slice(0, -1)
                    console.error("Gemini parse error:", e.message, "\nRaw:", text)
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: {} }
    }

    // --- Ollama process (SplitParser for real streaming) ---
    Process {
        id: ollamaProcess
        command: ["bash", "-c", ""]

        stdout: SplitParser {
            // fires once per newline — perfect for ndjson
            onRead: (line) => {
                if (line.trim() === "") return

                try {
                    const obj = JSON.parse(line)

                    if (obj.error) {
                        root.isLoading = false
                        root.isStreaming = false
                        root.hasError = true
                        root.errorMessage = obj.error
                        root.chatHistory = root.chatHistory.slice(0, -1)
                        root.streamingText = ""
                        root._ollamaAccumulated = ""
                        return
                    }

                    // First chunk — flip loading → streaming
                    if (root.isLoading) {
                        root.isLoading = false
                        root.isStreaming = true
                    }

                    if (obj.message?.content) {
                        root._ollamaAccumulated += obj.message.content
                        root.streamingText = root._ollamaAccumulated
                    }

                    if (obj.done === true) {
                        root.isStreaming = false
                        root.chatHistory = [...root.chatHistory, {
                            role: "model",
                            text: root._ollamaAccumulated
                        }]
                        root.streamingText = ""
                        root._ollamaAccumulated = ""
                    }

                } catch (e) {
                    // partial/malformed line — skip silently
                    console.warn("Ollama line parse skip:", e.message)
                }
            }
        }

        stderr: StdioCollector { onStreamFinished: {} }
    }
}
