#include "appearance/kawarp_background.h"
#include <QFile>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QTemporaryDir>
#include <QTest>

class FullscreenBackdropTest : public QObject {
  Q_OBJECT
private slots:
  void preservesFallbackAnimationState() {
    qmlRegisterType<KawarpBackground>("Orchard", 1, 0, "KawarpBackground");
    QTemporaryDir directory;
    QVERIFY(directory.isValid());
    QImage artwork(32, 32, QImage::Format_RGB32);
    artwork.fill(Qt::red);
    const QString path = directory.filePath("art.png");
    QVERIFY(artwork.save(path));
    QQmlEngine engine;
    QQmlComponent component(&engine);
    const QByteArray qml = QByteArrayLiteral("import QtQuick\nimport \"")
        + QUrl::fromLocalFile(QStringLiteral(ORCHARD_SOURCE_DIR "/app/qml/components/player")).toEncoded()
        + QByteArrayLiteral("\"\nFullscreenBackdrop { width: 800; height: 600; playing: false }");
    component.setData(qml, QUrl());
    QScopedPointer<QObject> root(component.create());
    QVERIFY2(root, qPrintable(component.errorString()));
    auto loader = [&]() -> QQuickItem * {
      for (auto *item : root->findChildren<QQuickItem *>())
        if (item->inherits("QQuickLoader")) return item;
      return nullptr;
    }();
    QVERIFY(loader);
    QVERIFY(loader->property("active").toBool());
    root->setProperty("thumbnail", QUrl::fromLocalFile(path));
    QTRY_VERIFY_WITH_TIMEOUT(!loader->property("active").toBool(), 3000);
    QVERIFY(!loader->property("item").value<QObject *>());
    root->setProperty("fallbackRotation", 137.0);
    root->setProperty("reveal", 0.5);
    QVERIFY(loader->property("active").toBool());
    QObject *fallback = loader->property("item").value<QObject *>();
    QVERIFY(fallback);
    QCOMPARE(fallback->property("rotation").toDouble(), 137.0);
    QTRY_COMPARE_WITH_TIMEOUT(fallback->property("opacity").toDouble(), 0.9, 1000);
    root->setProperty("reveal", 1.0);
    QVERIFY(!loader->property("active").toBool());
    QCOMPARE(root->property("fallbackRotation").toDouble(), 137.0);
    root->setProperty("thumbnail", QUrl());
    QTRY_VERIFY_WITH_TIMEOUT(loader->property("active").toBool(), 2000);
    QVERIFY(loader->property("item").value<QObject *>());
  }
};
QTEST_MAIN(FullscreenBackdropTest)
#include "fullscreen_backdrop_test.moc"
