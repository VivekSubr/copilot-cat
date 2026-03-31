#ifndef CATCONFIG_H
#define CATCONFIG_H

#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class CatConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(bool needsSetup READ needsSetup NOTIFY needsSetupChanged)

public:
    explicit CatConfig(QObject *parent = nullptr);

    // QML-callable
    Q_INVOKABLE void saveConfig(const QVariantMap &config);
    Q_INVOKABLE void fetchModels(const QString &apiKey);
    Q_INVOKABLE QString lastApiKey() const { return m_lastApiKey; }

    // C++ API
    void loadConfig(const QJsonObject &config);
    void setConfigPath(const QString &path);
    void setNeedsSetup(bool needs);
    void setBackend(const QString &backend);

    QString backend() const { return m_backend; }
    bool needsSetup() const { return m_needsSetup; }
    QString openRouterKey() const { return m_openRouterKey; }
    QString openRouterModel() const { return m_openRouterModel; }
    QString openRouterBaseUrl() const { return m_openRouterBaseUrl; }
    QString processCommand() const { return m_processCommand; }

signals:
    void backendChanged();
    void needsSetupChanged();
    void modelsReceived(const QVariantList &models);
    void modelsFetchFailed(const QString &error);
    void configSaved();

private:
    QNetworkAccessManager m_network;
    bool m_needsSetup = false;

    QString m_backend = "auto";
    QString m_openRouterKey;
    QString m_openRouterModel;
    QString m_openRouterBaseUrl;
    QString m_processCommand;
    QString m_configPath;
    QString m_lastApiKey;
};

#endif // CATCONFIG_H
