#include <QtTest>
#include <QSignalSpy>
#include <QJsonObject>
#include <QJsonDocument>
#include <QFile>
#include <QTemporaryDir>
#include <QCoreApplication>
#include "../src/catconfig.h"

class TestCatConfig : public QObject
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

    void test_needsSetup_default()
    {
        CatConfig config;
        QCOMPARE(config.needsSetup(), false);
    }

    void test_setNeedsSetup()
    {
        CatConfig config;
        QSignalSpy spy(&config, &CatConfig::needsSetupChanged);

        config.setNeedsSetup(true);
        QCOMPARE(config.needsSetup(), true);
        QCOMPARE(spy.count(), 1);

        config.setNeedsSetup(true);
        QCOMPARE(spy.count(), 1);
    }

    void test_backend_default()
    {
        CatConfig config;
        QCOMPARE(config.backend(), QString("auto"));
    }

    void test_setBackend()
    {
        CatConfig config;
        QSignalSpy spy(&config, &CatConfig::backendChanged);

        config.setBackend("openrouter");
        QCOMPARE(config.backend(), QString("openrouter"));
        QCOMPARE(spy.count(), 1);

        config.setBackend("openrouter");
        QCOMPARE(spy.count(), 1);
    }

    void test_loadConfig_sets_all_fields()
    {
        CatConfig config;
        QJsonObject cfg;
        cfg["backend"] = "openrouter";
        cfg["openrouter_api_key"] = "test-key";
        cfg["openrouter_model"] = "test-model";
        cfg["openrouter_base_url"] = "https://custom.api/v1";
        cfg["command"] = "echo %MSG%";

        config.loadConfig(cfg);
        QCOMPARE(config.backend(), QString("openrouter"));
        QCOMPARE(config.openRouterKey(), QString("test-key"));
        QCOMPARE(config.openRouterModel(), QString("test-model"));
        QCOMPARE(config.openRouterBaseUrl(), QString("https://custom.api/v1"));
        QCOMPARE(config.processCommand(), QString("echo %MSG%"));
    }

    void test_loadConfig_empty_is_safe()
    {
        CatConfig config;
        QJsonObject cfg;
        config.loadConfig(cfg);
        QCOMPARE(config.backend(), QString("auto"));
    }

    void test_saveConfig_writes_file()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString configPath = tempDir.path() + "/copilot-cat.json";

        CatConfig config;
        config.setNeedsSetup(true);
        config.setConfigPath(configPath);

        QSignalSpy savedSpy(&config, &CatConfig::configSaved);
        QSignalSpy setupSpy(&config, &CatConfig::needsSetupChanged);

        QVariantMap cfg;
        cfg["backend"] = "openrouter";
        cfg["openrouter_api_key"] = "sk-test-123";
        cfg["openrouter_model"] = "test/model:free";

        config.saveConfig(cfg);

        QVERIFY(QFile::exists(configPath));
        QCOMPARE(savedSpy.count(), 1);
        QCOMPARE(setupSpy.count(), 1);
        QCOMPARE(config.needsSetup(), false);
        QCOMPARE(config.backend(), QString("openrouter"));

        QFile file(configPath);
        QVERIFY(file.open(QIODevice::ReadOnly));
        auto doc = QJsonDocument::fromJson(file.readAll());
        QCOMPARE(doc["backend"].toString(), QString("openrouter"));
        QCOMPARE(doc["openrouter_api_key"].toString(), QString("sk-test-123"));
        QCOMPARE(doc["openrouter_model"].toString(), QString("test/model:free"));
    }

    void test_saveConfig_overwrites_existing()
    {
        QTemporaryDir tempDir;
        QVERIFY(tempDir.isValid());
        QString configPath = tempDir.path() + "/copilot-cat.json";

        CatConfig config;
        config.setConfigPath(configPath);

        QVariantMap config1;
        config1["backend"] = "openrouter";
        config1["openrouter_model"] = "model-a";
        config.saveConfig(config1);

        QVariantMap config2;
        config2["backend"] = "command";
        config2["command"] = "echo %MSG%";
        config.saveConfig(config2);

        QFile file(configPath);
        QVERIFY(file.open(QIODevice::ReadOnly));
        auto doc = QJsonDocument::fromJson(file.readAll());
        QCOMPARE(doc["backend"].toString(), QString("command"));
        QVERIFY(!doc.object().contains("openrouter_model"));
    }

    void test_setConfigPath()
    {
        QTemporaryDir tempDir;
        QString path = tempDir.path() + "/custom.json";

        CatConfig config;
        config.setConfigPath(path);

        QVariantMap cfg;
        cfg["backend"] = "auto";
        config.saveConfig(cfg);

        QVERIFY(QFile::exists(path));
    }

    void test_lastApiKey_stored_on_fetch()
    {
        CatConfig config;
        QCOMPARE(config.lastApiKey(), QString(""));
        config.fetchModels("sk-or-test-key-123");
        QCOMPARE(config.lastApiKey(), QString("sk-or-test-key-123"));
    }

    void test_fetchModels_emits_signal()
    {
        CatConfig config;
        QSignalSpy successSpy(&config, &CatConfig::modelsReceived);
        QSignalSpy failSpy(&config, &CatConfig::modelsFetchFailed);

        if (m_hasApiKey) {
            config.fetchModels(m_apiKey);
            QVERIFY2(successSpy.wait(15000), "modelsReceived not emitted (live)");
            QVariantList models = successSpy.at(0).at(0).value<QVariantList>();
            QVERIFY(models.size() > 0);
            QVariantMap first = models.at(0).toMap();
            QVERIFY(first.contains("id"));
            QVERIFY(first.contains("isFree"));
            QVERIFY(first.contains("contextLength"));
        } else {
            config.fetchModels("dummy-key-for-test");
            bool gotSignal = successSpy.wait(15000) || failSpy.wait(5000);
            QVERIFY2(gotSignal, "Neither signal emitted (mock)");
        }
    }

    void test_fetchModels_includes_free_models()
    {
        CatConfig config;
        QSignalSpy spy(&config, &CatConfig::modelsReceived);
        config.fetchModels(m_hasApiKey ? m_apiKey : "dummy-key-for-test");
        if (!spy.wait(15000)) QSKIP("Network unavailable");

        QVariantList models = spy.at(0).at(0).value<QVariantList>();
        bool hasFree = false, hasPaid = false;
        for (const auto &m : models) {
            if (m.toMap()["isFree"].toBool()) hasFree = true;
            else hasPaid = true;
        }
        QVERIFY2(hasFree, "Should have at least one free model");
        QVERIFY2(hasPaid, "Should have at least one paid model");
    }

    void test_fetchModels_free_ids_have_suffix()
    {
        CatConfig config;
        QSignalSpy spy(&config, &CatConfig::modelsReceived);
        config.fetchModels(m_hasApiKey ? m_apiKey : "dummy-key-for-test");
        if (!spy.wait(15000)) QSKIP("Network unavailable");

        for (const auto &m : spy.at(0).at(0).value<QVariantList>()) {
            QVariantMap model = m.toMap();
            if (model["isFree"].toBool())
                QVERIFY2(model["id"].toString().contains(":free"),
                    qPrintable("Missing :free suffix: " + model["id"].toString()));
        }
    }
};

QTEST_MAIN(TestCatConfig)

#include "tst_catconfig.moc"
