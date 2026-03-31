#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMutex>
#include <cstdio>
#include <cstring>
#include "catconfig.h"
#include "copilotbridge.h"

static QFile *g_logFile = nullptr;
static QMutex g_logMutex;

static void logMessageHandler(QtMsgType type, const QMessageLogContext &ctx, const QString &msg)
{
    Q_UNUSED(ctx)
    const char *level;
    switch (type) {
    case QtDebugMsg:    level = "DEBUG"; break;
    case QtInfoMsg:     level = "INFO";  break;
    case QtWarningMsg:  level = "WARN";  break;
    case QtCriticalMsg: level = "ERROR"; break;
    case QtFatalMsg:    level = "FATAL"; break;
    }

    QString line = QString("[%1] [%2] %3\n")
        .arg(QDateTime::currentDateTime().toString("yyyy-MM-dd hh:mm:ss.zzz"))
        .arg(level)
        .arg(msg);

    QMutexLocker lock(&g_logMutex);
    if (g_logFile && g_logFile->isOpen()) {
        g_logFile->write(line.toUtf8());
        g_logFile->flush();
    }

    // Also print to stderr for console debugging
    fprintf(stderr, "%s", line.toUtf8().constData());
}

static void printHelp()
{
    fprintf(stderr,
        "Copilot Cat - Desktop pet AI assistant\n"
        "\n"
        "Usage: copilot-cat [options]\n"
        "\n"
        "Options:\n"
        "  --help, -h               Show this help message and exit\n"
        "  --version, -v            Show version and exit\n"
        "  --backend <name>         Chat backend: auto, mcp, openrouter, command\n"
        "  --config <file>          Load config from JSON file\n"
        "\n"
        "Backends:\n"
        "  auto        Try MCP, then OpenRouter, then command, then cat puns (default)\n"
        "  mcp         MCP server via WebSocket (ws://127.0.0.1:9922)\n"
        "  openrouter  OpenRouter API (requires openrouter_api_key)\n"
        "  command     Custom command (requires command)\n"
        "\n"
        "Config file (copilot-cat.json):\n"
        "  Auto-loaded from exe directory if present. Use --config to override.\n"
        "  {\n"
        "    \"backend\": \"openrouter\",\n"
        "    \"openrouter_api_key\": \"sk-or-...\",\n"
        "    \"openrouter_model\": \"openai/gpt-4o-mini\",\n"
        "    \"openrouter_base_url\": \"https://openrouter.ai/api/v1\",\n"
        "    \"command\": \"my-ai-tool %%MSG%%\"\n"
        "  }\n"
        "  Environment variables (OPENROUTER_API_KEY, etc.) are used as defaults;\n"
        "  config file values override them; CLI flags override config file.\n"
        "\n"
        "Examples:\n"
        "  copilot-cat                          # auto-detect (loads copilot-cat.json)\n"
        "  copilot-cat --backend mcp            # use MCP server only\n"
        "  copilot-cat --config my-config.json  # use custom config file\n"
    );
}

static QJsonObject loadJsonFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    auto doc = QJsonDocument::fromJson(file.readAll());
    if (!doc.isObject()) {
        fprintf(stderr, "[copilot-cat] Warning: %s is not a valid JSON object\n",
                path.toUtf8().constData());
        return {};
    }
    fprintf(stderr, "[copilot-cat] Loaded config: %s\n", path.toUtf8().constData());
    return doc.object();
}

int main(int argc, char *argv[])
{
    const char *backend = nullptr;
    const char *configPath = nullptr;

    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--help") == 0 || std::strcmp(argv[i], "-h") == 0) {
            printHelp();
            return 0;
        }
        if (std::strcmp(argv[i], "--version") == 0 || std::strcmp(argv[i], "-v") == 0) {
            fprintf(stderr, "Copilot Cat 1.0.0\n");
            return 0;
        }
        if (std::strcmp(argv[i], "--backend") == 0 && i + 1 < argc) {
            backend = argv[++i];
        }
        if (std::strcmp(argv[i], "--config") == 0 && i + 1 < argc) {
            configPath = argv[++i];
        }
    }

    // Enable transparent windows on Windows
    QQuickWindow::setDefaultAlphaBuffer(true);

    QGuiApplication app(argc, argv);

    // Set up file logging — recreate copilot-cat.log next to exe on every launch
    QString logPath = QCoreApplication::applicationDirPath() + "/copilot-cat.log";
    static QFile logFile(logPath);
    if (logFile.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        g_logFile = &logFile;
        qInstallMessageHandler(logMessageHandler);
    }
    qInfo() << "Copilot Cat 1.0.0 starting";
    qInfo() << "Log file:" << logPath;
    QQuickStyle::setStyle("Basic");
    app.setApplicationName("Copilot Cat");
    app.setOrganizationName("CopilotCat");

    CatConfig config;
    CopilotBridge bridge(&config);

    // Load config: explicit --config, or auto-detect copilot-cat.json next to exe
    bool configLoaded = false;
    if (configPath) {
        QJsonObject cfg = loadJsonFile(QString::fromUtf8(configPath));
        if (!cfg.isEmpty()) {
            config.loadConfig(cfg);
            configLoaded = true;
        }
        config.setConfigPath(QString::fromUtf8(configPath));
    } else {
        QString autoConfig = QCoreApplication::applicationDirPath() + "/copilot-cat.json";
        config.setConfigPath(autoConfig);
        if (QFileInfo::exists(autoConfig)) {
            QJsonObject cfg = loadJsonFile(autoConfig);
            if (!cfg.isEmpty()) {
                config.loadConfig(cfg);
                configLoaded = true;
            }
        }
    }

    // If no config was loaded, trigger first-run setup wizard
    if (!configLoaded)
        config.setNeedsSetup(true);

    // CLI --backend overrides config file
    if (backend)
        config.setBackend(QString::fromUtf8(backend));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("catConfig", &config);
    engine.rootContext()->setContextProperty("copilotBridge", &bridge);

    const QUrl url(u"qrc:/CopilotCat/qml/Main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
