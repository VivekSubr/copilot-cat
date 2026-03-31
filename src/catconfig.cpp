#include "catconfig.h"
#include <QCoreApplication>
#include <QDesktopServices>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

static const char *GITHUB_CLIENT_ID = "Iv1.b507a08c87ecfe98";
static const char *GITHUB_SCOPES = "read:user";
static const char *VSCODE_VERSION = "1.100.0";
static const char *COPILOT_CHAT_VERSION = "copilot-chat/0.26.7";
static const char *COPILOT_USER_AGENT = "GitHubCopilotChat/0.26.7";

CatConfig::CatConfig(QObject *parent)
    : QObject(parent)
{
    m_openRouterKey = qEnvironmentVariable("OPENROUTER_API_KEY", "");
    m_openRouterModel = qEnvironmentVariable("OPENROUTER_MODEL", "openai/gpt-4o-mini");
    m_openRouterBaseUrl = qEnvironmentVariable("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1");
    m_processCommand = qEnvironmentVariable("COPILOT_CAT_CMD", "");

    connect(&m_authPollTimer, &QTimer::timeout, this, &CatConfig::pollForAccessToken);
}

void CatConfig::setBackend(const QString &backend)
{
    if (m_backend != backend) {
        m_backend = backend;
        emit backendChanged();
    }
}

void CatConfig::setNeedsSetup(bool needs)
{
    if (m_needsSetup != needs) {
        m_needsSetup = needs;
        emit needsSetupChanged();
    }
}

void CatConfig::setConfigPath(const QString &path)
{
    m_configPath = path;
}

void CatConfig::loadConfig(const QJsonObject &config)
{
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
    if (config.contains("github_token")) {
        m_githubToken = config["github_token"].toString();
        if (m_backend == "copilot" && !m_githubToken.isEmpty())
            fetchCopilotToken();
    }
}

void CatConfig::saveConfig(const QVariantMap &config)
{
    QJsonObject json = QJsonObject::fromVariantMap(config);
    QString path = m_configPath;
    if (path.isEmpty())
        path = QCoreApplication::applicationDirPath() + "/copilot-cat.json";

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "Failed to write config:" << path;
        return;
    }
    file.write(QJsonDocument(json).toJson(QJsonDocument::Indented));
    file.close();
    qInfo() << "Config saved:" << path;

    loadConfig(json);
    setNeedsSetup(false);
    emit configSaved();
}

void CatConfig::fetchModels(const QString &apiKey)
{
    m_lastApiKey = apiKey;
    qInfo() << "fetchModels: storing key len=" << apiKey.length();
    QNetworkRequest req(QUrl("https://openrouter.ai/api/v1/models"));
    req.setRawHeader("Authorization", ("Bearer " + apiKey).toUtf8());

    auto *reply = m_network.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit modelsFetchFailed(reply->errorString());
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        QJsonArray data = doc["data"].toArray();
        QVariantList models;

        for (const auto &item : data) {
            auto obj = item.toObject();
            QString id = obj["id"].toString();
            bool isFree = id.contains(":free");
            int ctx = obj["context_length"].toInt();
            QString promptPrice = obj["pricing"].toObject()["prompt"].toString();
            QString complPrice = obj["pricing"].toObject()["completion"].toString();

            QVariantMap m;
            m["id"] = id;
            m["isFree"] = isFree;
            m["contextLength"] = ctx;
            m["promptPrice"] = promptPrice;
            m["completionPrice"] = complPrice;
            models.append(m);
        }

        qInfo() << "Fetched" << models.size() << "models from OpenRouter";
        emit modelsReceived(models);
    });
}

// === Copilot Device Flow Auth ===

void CatConfig::startCopilotAuth()
{
    qInfo() << "Starting Copilot device flow auth...";

    QJsonObject body;
    body["client_id"] = QString(GITHUB_CLIENT_ID);
    body["scope"] = QString(GITHUB_SCOPES);

    QNetworkRequest req(QUrl("https://github.com/login/device/code"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");

    auto *reply = m_network.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit copilotAuthFailed("Device code request failed: " + reply->errorString());
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        QString userCode = doc["user_code"].toString();
        QString verificationUri = doc["verification_uri"].toString();
        m_deviceCode = doc["device_code"].toString();
        m_pollInterval = doc["interval"].toInt(5);

        qInfo() << "Device code:" << userCode << "URI:" << verificationUri;

        // Open browser for user
        QDesktopServices::openUrl(QUrl(verificationUri));

        emit copilotDeviceCode(userCode, verificationUri);

        // Start polling for authorization
        m_authPollTimer.start(m_pollInterval * 1000);
    });
}

void CatConfig::cancelCopilotAuth()
{
    m_authPollTimer.stop();
    m_deviceCode.clear();
}

void CatConfig::pollForAccessToken()
{
    QJsonObject body;
    body["client_id"] = QString(GITHUB_CLIENT_ID);
    body["device_code"] = m_deviceCode;
    body["grant_type"] = QString("urn:ietf:params:oauth:grant-type:device_code");

    QNetworkRequest req(QUrl("https://github.com/login/oauth/access_token"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Accept", "application/json");

    auto *reply = m_network.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            emit copilotAuthFailed("Token poll failed: " + reply->errorString());
            m_authPollTimer.stop();
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        QString error = doc["error"].toString();

        if (error == "authorization_pending") {
            // Still waiting — keep polling
            return;
        }
        if (error == "slow_down") {
            m_pollInterval += 5;
            m_authPollTimer.setInterval(m_pollInterval * 1000);
            return;
        }
        if (!error.isEmpty()) {
            m_authPollTimer.stop();
            emit copilotAuthFailed("Auth error: " + error + " - " + doc["error_description"].toString());
            return;
        }

        // Success — got the GitHub token
        m_authPollTimer.stop();
        m_githubToken = doc["access_token"].toString();
        qInfo() << "GitHub OAuth token obtained";

        // Now get the Copilot token
        fetchCopilotToken();
    });
}

void CatConfig::fetchCopilotToken()
{
    QNetworkRequest req(QUrl("https://api.github.com/copilot_internal/v2/token"));
    req.setRawHeader("Authorization", ("token " + m_githubToken).toUtf8());
    req.setRawHeader("Accept", "application/json");
    req.setRawHeader("editor-version", ("vscode/" + QString(VSCODE_VERSION)).toUtf8());
    req.setRawHeader("editor-plugin-version", COPILOT_CHAT_VERSION);
    req.setRawHeader("user-agent", COPILOT_USER_AGENT);

    auto *reply = m_network.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            auto body = reply->readAll();
            qWarning() << "Copilot token fetch failed:" << reply->errorString() << body.left(200);
            emit copilotAuthFailed("Failed to get Copilot token: " + reply->errorString());
            return;
        }

        auto doc = QJsonDocument::fromJson(reply->readAll());
        m_copilotToken = doc["token"].toString();
        int refreshIn = doc["refresh_in"].toInt(1500);

        qInfo() << "Copilot token obtained, refresh in" << refreshIn << "s";

        scheduleCopilotTokenRefresh(refreshIn);

        // Save config with github token so we don't need to re-auth
        QVariantMap cfg;
        cfg["backend"] = "copilot";
        cfg["github_token"] = m_githubToken;
        saveConfig(cfg);

        emit copilotAuthSuccess();
    });
}

void CatConfig::scheduleCopilotTokenRefresh(int refreshInSecs)
{
    // Refresh 60s before expiry
    int ms = (refreshInSecs - 60) * 1000;
    if (ms < 60000) ms = 60000;

    m_tokenRefreshTimer.stop();
    m_tokenRefreshTimer.setSingleShot(true);
    connect(&m_tokenRefreshTimer, &QTimer::timeout, this, [this]() {
        qInfo() << "Refreshing Copilot token...";
        fetchCopilotToken();
    });
    m_tokenRefreshTimer.start(ms);
}
