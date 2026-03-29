#ifndef COPILOTBRIDGE_H
#define COPILOTBRIDGE_H

#include <QObject>
#include <QJsonArray>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QProcess>
#include <QString>

class CopilotBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString backend READ backend NOTIFY backendChanged)

public:
    explicit CopilotBridge(QObject *parent = nullptr);

    Q_INVOKABLE void sendMessage(const QString &message);
    bool busy() const { return m_busy; }

    QString backend() const { return m_backend; }
    void setBackend(const QString &backend);
    void loadConfig(const QJsonObject &config);

signals:
    void responseReceived(const QString &response);
    void errorOccurred(const QString &error);
    void busyChanged();
    void backendChanged();

private:
    void setBusy(bool busy);
    void sendViaOpenRouter(const QString &message);
    void sendViaProcess(const QString &message);
    void sendFallback(const QString &message);

    QProcess *m_process = nullptr;
    QNetworkAccessManager m_network;
    QJsonArray m_chatHistory;
    bool m_busy = false;

    QString m_backend = "auto";
    QString m_openRouterKey;
    QString m_openRouterModel;
    QString m_openRouterBaseUrl;
    QString m_processCommand;
};

#endif // COPILOTBRIDGE_H
