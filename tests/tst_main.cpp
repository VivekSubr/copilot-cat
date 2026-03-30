#include <QtQuickTest>
#include <QQmlEngine>
#include <QQmlContext>

class Setup : public QObject
{
    Q_OBJECT
public:
    Setup() {}

public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        engine->rootContext()->setContextProperty("assetPath",
            QString(ASSETS_DIR));
        engine->rootContext()->setContextProperty("qmlPath",
            QString(QML_DIR));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(copilot_cat_tests, Setup)

#include "tst_main.moc"
