#ifndef COPILOTBRIDGE_H
#define COPILOTBRIDGE_H

#include <QObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QProcess>
#include <QString>

class CatConfig;

class CopilotBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit CopilotBridge(CatConfig *config, QObject *parent = nullptr);

    Q_INVOKABLE void sendMessage(const QString &message);

    bool busy() const { return m_busy; }
    CatConfig *config() const { return m_config; }

signals:
    void responseReceived(const QString &response);
    void errorOccurred(const QString &error);
    void busyChanged();

private:
    void setBusy(bool busy);
    void sendViaOpenRouter(const QString &message);
    void sendViaCopilot(const QString &message);
    void sendViaProcess(const QString &message);
    void sendFallback(const QString &message);

    CatConfig *m_config;
    QProcess *m_process = nullptr;
    QNetworkAccessManager m_network;
    QJsonArray m_chatHistory;
    bool m_busy = false;
};

#endif // COPILOTBRIDGE_H
