#ifndef CATCONFIG_H
#define CATCONFIG_H

#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QString>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class CatConfig : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(bool needsSetup READ needsSetup NOTIFY needsSetupChanged)

public:
    explicit CatConfig(QObject *parent = nullptr);

    // QML-callable — OpenRouter
    Q_INVOKABLE void saveConfig(const QVariantMap &config);
    Q_INVOKABLE void fetchModels(const QString &apiKey);
    Q_INVOKABLE QString lastApiKey() const { return m_lastApiKey; }

    // QML-callable — Copilot device flow
    Q_INVOKABLE void startCopilotAuth();
    Q_INVOKABLE void cancelCopilotAuth();

    // C++ API
    void loadConfig(const QJsonObject &config);
    void setConfigPath(const QString &path);
    void setNeedsSetup(bool needs);
    void setBackend(const QString &backend);
    void initBackend();

    QString backend() const { return m_backend; }
    bool needsSetup() const { return m_needsSetup; }
    QString openRouterKey() const { return m_openRouterKey; }
    QString openRouterModel() const { return m_openRouterModel; }
    QString openRouterBaseUrl() const { return m_openRouterBaseUrl; }
    QString processCommand() const { return m_processCommand; }
    QString copilotToken() const { return m_copilotToken; }

signals:
    void backendChanged();
    void needsSetupChanged();
    void modelsReceived(const QVariantList &models);
    void modelsFetchFailed(const QString &error);
    void configSaved();
    // Copilot auth signals
    void copilotDeviceCode(const QString &userCode, const QString &verificationUri);
    void copilotAuthSuccess();
    void copilotAuthFailed(const QString &error);

private:
    void pollForAccessToken();
    void fetchCopilotToken();
    void scheduleCopilotTokenRefresh(int refreshInSecs);

    QNetworkAccessManager m_network;
    QTimer m_authPollTimer;
    QTimer m_tokenRefreshTimer;
    bool m_needsSetup = false;

    QString m_backend = "auto";
    QString m_openRouterKey;
    QString m_openRouterModel;
    QString m_openRouterBaseUrl;
    QString m_processCommand;
    QString m_configPath;
    QString m_lastApiKey;

    // Copilot auth state
    QString m_githubToken;
    QString m_copilotToken;
    QString m_deviceCode;
    int m_pollInterval = 5;
};

#endif // CATCONFIG_H
