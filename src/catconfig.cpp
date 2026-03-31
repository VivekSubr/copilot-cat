#include "catconfig.h"
#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>

CatConfig::CatConfig(QObject *parent)
    : QObject(parent)
{
    m_openRouterKey = qEnvironmentVariable("OPENROUTER_API_KEY", "");
    m_openRouterModel = qEnvironmentVariable("OPENROUTER_MODEL", "openai/gpt-4o-mini");
    m_openRouterBaseUrl = qEnvironmentVariable("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1");
    m_processCommand = qEnvironmentVariable("COPILOT_CAT_CMD", "");
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
