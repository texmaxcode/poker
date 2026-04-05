#include <QByteArray>
#include <QCoreApplication>
#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>

#include "game.hpp"
#include "persist_sqlite.hpp"
#include "poker_solver.hpp"
#include "session_store.hpp"
#include "toy_nash_solver.hpp"
#include "training_store.hpp"
#include "training_controller.hpp"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("TexasHoldemGym"));
    QCoreApplication::setApplicationName(QStringLiteral("Texas Hold'em Gym"));

    // Prefer Wayland when present so the bundled xcb plugin (needs distro libxcb-cursor on X11) is avoided.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
    {
        if (!qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY") || qgetenv("XDG_SESSION_TYPE") == "wayland")
            qputenv("QT_QPA_PLATFORM", QByteArrayLiteral("wayland"));
    }

    /// Allows QML `XMLHttpRequest` to load `qrc:` / local training JSON in RangeViewer and similar (Qt 6 default is restrictive).
    if (qEnvironmentVariableIsEmpty("QML_XHR_ALLOW_FILE_READ"))
        qputenv("QML_XHR_ALLOW_FILE_READ", QByteArrayLiteral("1"));

    QGuiApplication app(argc, argv);
    AppStateSqlite::init();
    const QIcon appIcon(QStringLiteral(":/assets/images/logo.png"));
    app.setWindowIcon(appIcon);
    // Matches `texas-holdem-gym.desktop` so shells resolve the taskbar/dock icon (Wayland uses app_id).
    app.setDesktopFileName(QStringLiteral("texas-holdem-gym"));

    // Bundled Google Fonts — families exposed to QML via Theme (Merriweather UI copy, Rye titles, Holtwood buttons, Roboto Mono numbers).
    QString appFontFamily = QStringLiteral("Merriweather");
    QString appFontFamilyDisplay = QStringLiteral("Rye");
    QString appFontFamilyButton = QStringLiteral("Holtwood One SC");
    QString appFontFamilyMono = QStringLiteral("Roboto Mono");
    {
        const auto familyFromQrc = [](const QString &qrcPath) -> QString {
            const int fid = QFontDatabase::addApplicationFont(qrcPath);
            if (fid == -1)
                return QString();
            const QStringList fams = QFontDatabase::applicationFontFamilies(fid);
            return fams.isEmpty() ? QString() : fams.first();
        };
        const QString merri = familyFromQrc(QStringLiteral(":/assets/fonts/Merriweather-opsz-wdth-wght.ttf"));
        if (!merri.isEmpty())
            appFontFamily = merri;
        const QString rye = familyFromQrc(QStringLiteral(":/assets/fonts/Rye-Regular.ttf"));
        if (!rye.isEmpty())
            appFontFamilyDisplay = rye;
        const QString holt = familyFromQrc(QStringLiteral(":/assets/fonts/HoltwoodOneSC-Regular.ttf"));
        if (!holt.isEmpty())
            appFontFamilyButton = holt;
        const QString mono = familyFromQrc(QStringLiteral(":/assets/fonts/RobotoMono-wght.ttf"));
        if (!mono.isEmpty())
            appFontFamilyMono = mono;

        QFont f = app.font();
        f.setFamily(appFontFamily);
        f.setWeight(QFont::Normal);
        f.setPointSizeF(13.0);
        app.setFont(f);
    }

    game poker_game;
    poker_game.loadPersistedSettings();
    /// Only insert missing keys — never a full `savePersistedSettings()` here: if `v1/smallBlind` was
    /// absent we may not have loaded strategies/ranges into memory, and a full save would clobber valid rows.
    if (AppStateSqlite::isOpen() && !AppStateSqlite::contains(QStringLiteral("v1/smallBlind")))
        poker_game.seedMissingPersistedSettings();
    PokerSolver poker_solver;
    ToyNashSolver toy_nash_solver;
    TrainingStore training_store;
    TrainingController trainer(&training_store);
    SessionStore session_store;

    // Headless self-test for debugging crashes in toy solver code paths.
    const QStringList args = QCoreApplication::arguments();
    if (args.contains(QStringLiteral("--selftest-leduc")))
    {
        const QVariantMap r = toy_nash_solver.solveLeduc(2000);
        const QString s = r.value(QStringLiteral("summaryText")).toString();
        qInfo().noquote() << s;
        return 0;
    }

    QQmlApplicationEngine engine;
    engine.addImportPath(QStringLiteral("qrc:/"));
    engine.rootContext()->setContextProperty(QStringLiteral("appFontFamily"), appFontFamily);
    engine.rootContext()->setContextProperty(QStringLiteral("appFontFamilyDisplay"), appFontFamilyDisplay);
    engine.rootContext()->setContextProperty(QStringLiteral("appFontFamilyButton"), appFontFamilyButton);
    engine.rootContext()->setContextProperty(QStringLiteral("appFontFamilyMono"), appFontFamilyMono);
    engine.rootContext()->setContextProperty(QStringLiteral("pokerGame"), &poker_game);
    engine.rootContext()->setContextProperty(QStringLiteral("pokerSolver"), &poker_solver);
    engine.rootContext()->setContextProperty(QStringLiteral("toyNashSolver"), &toy_nash_solver);
    engine.rootContext()->setContextProperty(QStringLiteral("trainingStore"), &training_store);
    engine.rootContext()->setContextProperty(QStringLiteral("trainer"), &trainer);
    engine.rootContext()->setContextProperty(QStringLiteral("sessionStore"), &session_store);

    QObject::connect(&app, &QGuiApplication::aboutToQuit, &poker_game, [&poker_game]() {
        poker_game.savePersistedSettings();
    });
    const QUrl mainUrl(QStringLiteral("qrc:/Main.qml"));
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [mainUrl](QObject *obj, const QUrl &objUrl) {
            if (!obj && mainUrl == objUrl)
                QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(mainUrl);

    if (engine.rootObjects().isEmpty())
        return -1;

    if (auto *const qw = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst()))
    {
        if (!appIcon.isNull())
            qw->setIcon(appIcon);
    }

    // After the scene tree is built, bind the Game Page (not the window) and start hand.
    QTimer::singleShot(400, &app, [&engine, &poker_game]() {
        QObject *const win = engine.rootObjects().isEmpty() ? nullptr : engine.rootObjects().first();
        QObject *const gp = win ? win->findChild<QObject *>(QStringLiteral("game_screen")) : nullptr;
        if (!gp)
        {
            qWarning() << "game_screen not found; table UI will not update.";
            return;
        }
        poker_game.setRootObject(gp);
        poker_game.beginNewHand();
    });

    return app.exec();
}
