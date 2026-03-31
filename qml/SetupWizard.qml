import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: wizard
    visible: false
    title: "Copilot Cat Setup"
    width: 360
    height: 320
    minimumWidth: 300
    minimumHeight: 280
    color: "#1e1e2e"
    x: (Screen.width - width) / 2
    y: (Screen.height - height) / 2

    signal setupComplete()

    property int currentStep: 0
    property string selectedBackend: ""
    property string selectedMethod: ""
    property string apiKey: ""
    property string selectedModel: ""
    property var modelList: []
    property bool fetchingModels: false
    property string copilotCode: ""
    property bool copilotAuthPending: false

    function start() {
        currentStep = 0;
        selectedBackend = "";
        selectedMethod = "";
        apiKey = "";
        selectedModel = "";
        modelList = [];
        visible = true;
    }

    Connections {
        target: catConfig
        function onModelsReceived(models) {
            console.log("SetupWizard: received " + models.length + " models");
            wizard.fetchingModels = false;
            var free = [];
            for (var i = 0; i < models.length; i++) {
                var m = models[i];
                if (m.isFree) free.push(m);
            }
            console.log("SetupWizard: " + free.length + " free models");
            wizard.modelList = free;
            wizard.currentStep = 3;
        }
        function onModelsFetchFailed(error) {
            wizard.fetchingModels = false;
            statusText.text = "Failed: " + error;
        }
        function onConfigSaved() {
            wizard.visible = false;
            wizard.setupComplete();
        }
        function onCopilotDeviceCode(userCode, verificationUri) {
            wizard.copilotCode = userCode;
            wizard.copilotAuthPending = true;
            wizard.currentStep = 4;
        }
        function onCopilotAuthSuccess() {
            wizard.copilotAuthPending = false;
            // configSaved is emitted by fetchCopilotToken -> saveConfig
        }
        function onCopilotAuthFailed(error) {
            wizard.copilotAuthPending = false;
            statusText.text = "Auth failed: " + error;
            wizard.currentStep = 0;
        }
    }

    // Title
    Text {
        id: titleText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        text: {
            if (currentStep === 0) return "Welcome! Choose a backend:";
            if (currentStep === 1) return "GitHub Copilot";
            if (currentStep === 2) return "Enter OpenRouter API key:";
            if (currentStep === 3) return "Select a model:";
            if (currentStep === 4) return "GitHub Authorization";
            return "";
        }
        font.pixelSize: 13
        font.bold: true
        color: "#cdd6f4"
    }

    // Status text (for errors/loading)
    Text {
        id: statusText
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 8
        text: wizard.fetchingModels ? "Fetching models..." : ""
        font.pixelSize: 10
        color: "#a6adc8"
    }

    // === STEP 0: Choose backend ===
    Column {
        visible: currentStep === 0
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: [
                { label: "GitHub Copilot", value: "copilot" },
                { label: "OpenRouter", value: "openrouter" }
            ]
            delegate: Rectangle {
                width: 180; height: 32
                radius: 8
                color: ma0.containsMouse ? "#45475a" : "#313244"
                border.color: "#89b4fa"; border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    font.pixelSize: 12
                    color: "#cdd6f4"
                }
                MouseArea {
                    id: ma0
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wizard.selectedBackend = modelData.value;
                        if (modelData.value === "copilot") wizard.currentStep = 1;
                        else wizard.currentStep = 2;
                    }
                }
            }
        }
    }

    // === STEP 1: GitHub Copilot — start device flow ===
    Column {
        visible: currentStep === 1
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 24

        Text {
            text: "Requires a GitHub Copilot subscription."
            font.pixelSize: 11
            color: "#a6adc8"
            width: parent.width
            wrapMode: Text.WordWrap
        }

        Rectangle {
            width: 180; height: 32
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: copilotStartMa.containsMouse ? "#45475a" : "#313244"
            border.color: "#a6e3a1"; border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Sign in with GitHub"
                font.pixelSize: 12
                color: "#cdd6f4"
            }
            MouseArea {
                id: copilotStartMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: catConfig.startCopilotAuth()
            }
        }

        Text {
            text: "< Back"
            font.pixelSize: 11
            color: "#6c7086"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wizard.currentStep = 0
            }
        }
    }

    // === STEP 4: Copilot — waiting for auth ===
    Column {
        visible: currentStep === 4
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 24

        Text {
            text: "Enter this code in your browser:"
            font.pixelSize: 12
            color: "#cdd6f4"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Rectangle {
            width: 160; height: 40
            radius: 10
            anchors.horizontalCenter: parent.horizontalCenter
            color: "#1e1e2e"
            border.color: "#a6e3a1"; border.width: 2

            TextEdit {
                anchors.centerIn: parent
                text: wizard.copilotCode
                font.pixelSize: 20
                font.bold: true
                font.letterSpacing: 4
                color: "#a6e3a1"
                readOnly: true
                selectByMouse: true
            }
        }

        Text {
            text: wizard.copilotAuthPending ? "Waiting for authorization..." : "Authorized!"
            font.pixelSize: 11
            color: "#a6adc8"
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
        }

        Text {
            text: "< Cancel"
            font.pixelSize: 11
            color: "#6c7086"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { catConfig.cancelCopilotAuth(); wizard.currentStep = 0; }
            }
        }
    }

    // === STEP 2: OpenRouter API key ===
    Column {
        visible: currentStep === 2
        anchors.centerIn: parent
        spacing: 10
        width: parent.width - 24

        TextField {
            id: apiKeyField
            width: parent.width
            height: 32
            placeholderText: "sk-or-v1-..."
            placeholderTextColor: "#6c7086"
            color: "#cdd6f4"
            font.pixelSize: 12
            background: Rectangle {
                radius: 8
                color: "#313244"
                border.color: apiKeyField.activeFocus ? "#89b4fa" : "#45475a"
                border.width: 1
            }
            onAccepted: {
                if (text.trim().length > 0 && !wizard.fetchingModels) {
                    wizard.fetchingModels = true;
                    statusText.text = "Fetching models...";
                    console.log("Fetch: field text prefix=" + text.substring(0, 8) + " len=" + text.length);
                    catConfig.fetchModels(text.trim());
                }
            }
        }

        Rectangle {
            id: fetchBtn
            width: 180; height: 32
            radius: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: fetchMa.containsMouse ? "#45475a" : "#313244"
            border.color: "#a6e3a1"; border.width: 1
            opacity: apiKeyField.text.length > 0 && !wizard.fetchingModels ? 1.0 : 0.5

            signal clicked()

            Text {
                anchors.centerIn: parent
                text: wizard.fetchingModels ? "Fetching..." : "Fetch free models"
                font.pixelSize: 12
                color: "#cdd6f4"
            }
            MouseArea {
                id: fetchMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (apiKeyField.text.trim().length === 0 || wizard.fetchingModels) return;
                    wizard.fetchingModels = true;
                    statusText.text = "Fetching models...";
                    console.log("Fetch btn: field text prefix=" + apiKeyField.text.substring(0, 8) + " len=" + apiKeyField.text.length);
                    catConfig.fetchModels(apiKeyField.text.trim());
                }
            }
        }

        Text {
            text: "< Back"
            font.pixelSize: 11
            color: "#6c7086"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wizard.currentStep = 0
            }
        }
    }

    // === STEP 3: Select model ===
    Column {
        visible: currentStep === 3
        anchors.fill: parent
        anchors.margins: 12
        anchors.topMargin: 32
        spacing: 4

        ListView {
            id: modelListView
            width: parent.width
            height: parent.height - 30
            clip: true
            model: wizard.modelList
            spacing: 3

            delegate: Rectangle {
                width: modelListView.width
                height: 28
                radius: 6
                color: modelMa.containsMouse ? "#45475a" : "#313244"
                border.color: "#585b70"; border.width: 1

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.id
                    font.pixelSize: 11
                    color: "#cdd6f4"
                    elide: Text.ElideRight
                    width: parent.width - 16
                }
                MouseArea {
                    id: modelMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        wizard.selectedModel = modelData.id;
                        var key = catConfig.lastApiKey();
                        console.log("Model select: key prefix=" + key.substring(0, 8) + " len=" + key.length + " model=" + modelData.id);
                        catConfig.saveConfig({
                            "backend": "openrouter",
                            "openrouter_api_key": key,
                            "openrouter_model": modelData.id
                        });
                    }
                }
            }
        }

        Text {
            text: "< Back"
            font.pixelSize: 11
            color: "#6c7086"
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: wizard.currentStep = 2
            }
        }
    }
}
