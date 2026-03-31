#include <QtTest>
#include <QSignalSpy>
#include <QJsonObject>
#include <QCoreApplication>
#include <QFile>
#include "../src/catconfig.h"
#include "../src/copilotbridge.h"

class TestCopilotBridge : public QObject
{
    Q_OBJECT

private:
    QString m_apiKey;
    bool m_hasApiKey = false;

    void loadApiKey()
    {
        QStringList searchPaths = {
            QCoreApplication::applicationDirPath() + "/.openrouter-key",
            QString(SOURCE_DIR) + "/.openrouter-key",
        };
        for (const auto &path : searchPaths) {
            QFile f(path);
            if (f.open(QIODevice::ReadOnly)) {
                m_apiKey = QString::fromUtf8(f.readAll()).trimmed();
                if (!m_apiKey.isEmpty()) {
                    m_hasApiKey = true;
                    qInfo() << "Using API key from" << path;
                    return;
                }
            }
        }
        qInfo() << "No .openrouter-key found — network tests will use mocks";
    }

private slots:
    void initTestCase()
    {
        loadApiKey();
    }

    void test_sendMessage_openrouter_no_key_emits_error()
    {
        CatConfig config;
        config.setBackend("openrouter");
        CopilotBridge bridge(&config);

        QSignalSpy errorSpy(&bridge, &CopilotBridge::errorOccurred);
        bridge.sendMessage("hello");

        QCOMPARE(errorSpy.count(), 1);
        QVERIFY2(errorSpy.at(0).at(0).toString().contains("OPENROUTER_API_KEY"),
            "Expected key error");
    }

    void test_sendMessage_openrouter_invalid_key_401()
    {
        CatConfig config;
        QJsonObject cfg;
        cfg["backend"] = "openrouter";
        cfg["openrouter_api_key"] = "invalid-key";
        cfg["openrouter_model"] = "openai/gpt-4o-mini";
        config.loadConfig(cfg);

        CopilotBridge bridge(&config);
        QSignalSpy errorSpy(&bridge, &CopilotBridge::errorOccurred);
        QSignalSpy responseSpy(&bridge, &CopilotBridge::responseReceived);

        bridge.sendMessage("hello");

        bool gotError = errorSpy.wait(15000);
        if (!gotError && responseSpy.count() == 0)
            QSKIP("Network unavailable");

        QVERIFY2(errorSpy.count() > 0, "Should get error with invalid key");
        QString err = errorSpy.at(0).at(0).toString();
        QVERIFY2(err.contains("401") || err.contains("auth") || err.contains("Auth"),
            qPrintable("Expected 401/auth error, got: " + err));
    }

    void test_sendMessage_openrouter_valid_key_success()
    {
        if (!m_hasApiKey)
            QSKIP("No .openrouter-key — skipping live chat test");

        CatConfig config;
        QJsonObject cfg;
        cfg["backend"] = "openrouter";
        cfg["openrouter_api_key"] = m_apiKey;
        cfg["openrouter_model"] = "google/gemma-3-4b-it:free";
        config.loadConfig(cfg);

        CopilotBridge bridge(&config);
        QSignalSpy responseSpy(&bridge, &CopilotBridge::responseReceived);
        QSignalSpy errorSpy(&bridge, &CopilotBridge::errorOccurred);

        bridge.sendMessage("say meow");

        bool gotResponse = responseSpy.wait(15000);
        if (!gotResponse && errorSpy.count() > 0) {
            QString err = errorSpy.at(0).at(0).toString();
            if (err.contains("429")) QSKIP("Rate limited");
            QFAIL(qPrintable("Expected response, got error: " + err));
        }
        QVERIFY2(gotResponse, "Should get a response with valid key");
        QVERIFY2(!responseSpy.at(0).at(0).toString().isEmpty(), "Response should not be empty");
    }

    void test_sendMessage_busy_blocks_concurrent()
    {
        CatConfig config;
        QJsonObject cfg;
        cfg["backend"] = "openrouter";
        cfg["openrouter_api_key"] = "any-key";
        cfg["openrouter_model"] = "any-model";
        config.loadConfig(cfg);

        CopilotBridge bridge(&config);
        bridge.sendMessage("first");
        QCOMPARE(bridge.busy(), true);

        QSignalSpy errorSpy(&bridge, &CopilotBridge::errorOccurred);
        bridge.sendMessage("second");
        QCOMPARE(errorSpy.count(), 0);
    }

    void test_sendMessage_fallback_when_no_backend()
    {
        CatConfig config;
        config.setBackend("auto");

        CopilotBridge bridge(&config);
        QSignalSpy responseSpy(&bridge, &CopilotBridge::responseReceived);
        bridge.sendMessage("hello");

        QVERIFY2(responseSpy.wait(3000), "Fallback should emit response");
        QVERIFY2(!responseSpy.at(0).at(0).toString().isEmpty(), "Fallback should return a cat pun");
    }

    void test_sendMessage_command_no_cmd_emits_error()
    {
        CatConfig config;
        config.setBackend("command");

        CopilotBridge bridge(&config);
        QSignalSpy errorSpy(&bridge, &CopilotBridge::errorOccurred);
        bridge.sendMessage("hello");

        QCOMPARE(errorSpy.count(), 1);
        QVERIFY2(errorSpy.at(0).at(0).toString().contains("COPILOT_CAT_CMD"),
            "Expected command error");
    }

    void test_busy_default_false()
    {
        CatConfig config;
        CopilotBridge bridge(&config);
        QCOMPARE(bridge.busy(), false);
    }
};

QTEST_MAIN(TestCopilotBridge)

#include "tst_copilotbridge.moc"
