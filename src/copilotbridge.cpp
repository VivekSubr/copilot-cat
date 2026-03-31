#include "copilotbridge.h"
#include "catconfig.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
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

CopilotBridge::CopilotBridge(CatConfig *config, QObject *parent)
    : QObject(parent), m_config(config)
{
}

void CopilotBridge::sendMessage(const QString &message)
{
    if (m_busy)
        return;

    setBusy(true);

    QString backend = m_config->backend();

    if (backend == "openrouter") {
        if (!m_config->openRouterKey().isEmpty()) { sendViaOpenRouter(message); return; }
        emit errorOccurred("OPENROUTER_API_KEY not set.");
        setBusy(false);
        return;
    }
    if (backend == "command") {
        if (!m_config->processCommand().isEmpty()) { sendViaProcess(message); return; }
        emit errorOccurred("COPILOT_CAT_CMD not set.");
        setBusy(false);
        return;
    }

    // "auto" — try in priority order
    if (!m_config->openRouterKey().isEmpty())
        sendViaOpenRouter(message);
    else if (!m_config->processCommand().isEmpty())
        sendViaProcess(message);
    else
        sendFallback(message);
}

void CopilotBridge::sendViaOpenRouter(const QString &message)
{
    QJsonObject userMsg;
    userMsg["role"] = "user";
    userMsg["content"] = message;
    m_chatHistory.append(userMsg);

    while (m_chatHistory.size() > 20)
        m_chatHistory.removeFirst();

    QJsonArray messages;
    QJsonObject sysMsg;
    sysMsg["role"] = "user";
    sysMsg["content"] = QString("[Instructions] ") + QString(SYSTEM_PROMPT);
    messages.append(sysMsg);
    QJsonObject ack;
    ack["role"] = "assistant";
    ack["content"] = QString("Understood! I'm Copilot Cat, ready to help!");
    messages.append(ack);
    for (const auto &msg : m_chatHistory)
        messages.append(msg);

    QJsonObject body;
    body["model"] = m_config->openRouterModel();
    body["messages"] = messages;
    body["max_tokens"] = 200;

    QNetworkRequest req(QUrl(m_config->openRouterBaseUrl() + "/chat/completions"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", ("Bearer " + m_config->openRouterKey()).toUtf8());
    req.setRawHeader("HTTP-Referer", "https://github.com/copilot-cat");
    req.setRawHeader("X-Title", "Copilot Cat");

    auto *reply = m_network.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            auto body = reply->readAll();
            int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            qWarning() << "OpenRouter HTTP" << status << reply->errorString();
            qWarning() << "OpenRouter response body:" << body.left(500);
            emit errorOccurred(QString("OpenRouter HTTP %1: %2").arg(status).arg(reply->errorString()));
            setBusy(false);
            return;
        }

        auto data = reply->readAll();
        auto doc = QJsonDocument::fromJson(data);
        QString text = doc["choices"][0]["message"]["content"].toString().trimmed();

        if (text.isEmpty()) {
            qWarning() << "OpenRouter empty response:" << data.left(500);
            emit errorOccurred("Empty response from OpenRouter.");
            setBusy(false);
            return;
        }

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
            if (status == QProcess::NormalExit && exitCode == 0 && !output.isEmpty())
                emit responseReceived(output);
            else if (output.isEmpty())
                emit errorOccurred("No response received.");
            else
                emit responseReceived(output);
            setBusy(false);
        });

    connect(m_process, &QProcess::errorOccurred, this,
        [this](QProcess::ProcessError error) {
            Q_UNUSED(error)
            emit errorOccurred("Failed to start AI process. Check your command configuration.");
            setBusy(false);
        });

    QString expandedCommand = m_config->processCommand();
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
