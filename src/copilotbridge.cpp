#include "copilotbridge.h"
#include <QCoreApplication>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRandomGenerator>
#include <QStandardPaths>
#include <QTimer>

static const char *SYSTEM_PROMPT =
    "You are Copilot Cat, a helpful and playful desktop pet AI assistant. "
    "Keep responses short (1-3 sentences). Be friendly, occasionally use cat puns. "
    "You help with coding questions, general knowledge, and chat.";

CopilotBridge::CopilotBridge(QObject *parent)
    : QObject(parent)
{
    m_openRouterKey = qEnvironmentVariable("OPENROUTER_API_KEY", "");
    m_openRouterModel = qEnvironmentVariable("OPENROUTER_MODEL", "openai/gpt-4o-mini");
    m_openRouterBaseUrl = qEnvironmentVariable("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1");
    m_processCommand = qEnvironmentVariable("COPILOT_CAT_CMD", "");
}

void CopilotBridge::setBackend(const QString &backend)
{
    if (m_backend != backend) {
        m_backend = backend;
        emit backendChanged();
    }
}

void CopilotBridge::loadConfig(const QJsonObject &config)
{
    // Config JSON values override env vars; env vars remain as defaults
    if (config.contains("backend"))
        setBackend(config["backend"].toString());
    if (config.contains("openrouter_api_key"))
        m_openRouterKey = config["openrouter_api_key"].toString();
    if (config.contains("openrouter_model"))
        m_openRouterModel = config["openrouter_model"].toString();
    if (config.contains("openrouter_base_url"))
        m_openRouterBaseUrl = config["openrouter_base_url"].toString();
    if (config.contains("command"))
        m_processCommand = config["command"].toString();
}

void CopilotBridge::sendMessage(const QString &message)
{
    if (m_busy)
        return;

    setBusy(true);

    // "mcp" backend is handled in QML via WebSocket, not here
    if (m_backend == "openrouter") {
        if (!m_openRouterKey.isEmpty()) { sendViaOpenRouter(message); return; }
        emit errorOccurred("OPENROUTER_API_KEY not set.");
        setBusy(false);
        return;
    }
    if (m_backend == "command") {
        if (!m_processCommand.isEmpty()) { sendViaProcess(message); return; }
        emit errorOccurred("COPILOT_CAT_CMD not set.");
        setBusy(false);
        return;
    }

    // "auto" — try in priority order
    if (!m_openRouterKey.isEmpty())
        sendViaOpenRouter(message);
    else if (!m_processCommand.isEmpty())
        sendViaProcess(message);
    else
        sendFallback(message);
}

void CopilotBridge::sendViaOpenRouter(const QString &message)
{
    // Add user message to history
    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = message;
    m_chatHistory.append(userMsg);

    // Trim history to last 20 messages
    while (m_chatHistory.size() > 20)
        m_chatHistory.removeFirst();

    // Build messages array with system prompt
    QJsonArray messages;
    QJsonObject sysMsg;
    sysMsg["role"] = "system";
    sysMsg["content"] = QString(SYSTEM_PROMPT);
    messages.append(sysMsg);
    for (const auto &msg : m_chatHistory)
        messages.append(msg);

    QJsonObject body;
    body["model"] = m_openRouterModel;
    body["messages"] = messages;
    body["max_tokens"] = 200;

    QNetworkRequest req(QUrl(m_openRouterBaseUrl + "/chat/completions"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", ("Bearer " + m_openRouterKey).toUtf8());
    req.setRawHeader("HTTP-Referer", "https://github.com/copilot-cat");
    req.setRawHeader("X-Title", "Copilot Cat");

    auto *reply = m_network.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit errorOccurred(QString("OpenRouter: %1").arg(reply->errorString()));
            setBusy(false);
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        QString text = doc["choices"][0]["message"]["content"].toString().trimmed();

        if (text.isEmpty()) {
            emit errorOccurred("Empty response from OpenRouter.");
            setBusy(false);
            return;
        }

        // Add assistant reply to history
        QJsonObject assistantMsg;
        assistantMsg["role"] = "assistant";
        assistantMsg["content"] = text;
        m_chatHistory.append(assistantMsg);

        emit responseReceived(text);
        setBusy(false);
    });
}

void CopilotBridge::sendViaProcess(const QString &message)
{
    if (m_process) {
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_process = new QProcess(this);
    m_process->setProcessChannelMode(QProcess::MergedChannels);

    connect(m_process, &QProcess::finished, this,
        [this](int exitCode, QProcess::ExitStatus status) {
            QString output = QString::fromUtf8(m_process->readAllStandardOutput()).trimmed();

            if (status == QProcess::NormalExit && exitCode == 0 && !output.isEmpty()) {
                emit responseReceived(output);
            } else if (output.isEmpty()) {
                emit errorOccurred("No response received.");
            } else {
                emit responseReceived(output);
            }

            setBusy(false);
        });

    connect(m_process, &QProcess::errorOccurred, this,
        [this](QProcess::ProcessError error) {
            Q_UNUSED(error)
            emit errorOccurred("Failed to start AI process. Check your command configuration.");
            setBusy(false);
        });

    QString expandedCommand = m_processCommand;
    expandedCommand.replace("%MSG%", message);

#ifdef Q_OS_WIN
    m_process->start("cmd.exe", {"/c", expandedCommand});
#else
    m_process->start("/bin/sh", {"-c", expandedCommand});
#endif
}

void CopilotBridge::sendFallback(const QString &message)
{
    QStringList catResponses = {
        "Meow! You said: %1 ...purrfect question!",
        "*purrs thoughtfully* %1 ...let me paws and think about that.",
        "As a wise cat once said about '%1': nap first, answer later.",
        "*stretches* Hmm, '%1'? That's a pawsitively interesting thought!",
        "Processing '%1'... *knocks response off table*"
    };
    int idx = QRandomGenerator::global()->bounded(catResponses.size());
    QString response = catResponses[idx].arg(message);

    QTimer::singleShot(800, this, [this, response]() {
        emit responseReceived(response);
        setBusy(false);
    });
}

void CopilotBridge::setBusy(bool busy)
{
    if (m_busy != busy) {
        m_busy = busy;
        emit busyChanged();
    }
}
