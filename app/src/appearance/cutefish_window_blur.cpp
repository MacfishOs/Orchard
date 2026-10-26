/*
 * Copyright (C) 2026 Cutefish / Orchard
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "cutefish_window_blur.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QTimer>
#include <cstring>

#if defined(Q_OS_LINUX)
#include <qpa/qplatformnativeinterface.h>
#include "cutefish-surface-blur-v1-client-protocol.h"

#if __has_include(<xcb/xcb.h>)
#include <xcb/xcb.h>
#define HAVE_XCB 1
#endif

void cutefishRegistryHandler(void *data, struct wl_registry *registry,
                             uint32_t name, const char *interface, uint32_t /*version*/)
{
    auto *self = static_cast<CutefishWindowBlur *>(data);
    if (std::strcmp(interface, cutefish_surface_blur_v1_interface.name) == 0) {
        self->m_surfaceBlur = static_cast<cutefish_surface_blur_v1 *>(
            wl_registry_bind(registry, name, &cutefish_surface_blur_v1_interface, 1));
        self->m_active = true;
        emit self->activeChanged();
        self->updateBlur();
    }
}

void cutefishRegistryRemove(void * /*data*/, struct wl_registry * /*registry*/, uint32_t /*name*/)
{
}

static const struct wl_registry_listener s_registryListener = {
    cutefishRegistryHandler,
    cutefishRegistryRemove
};
#endif

CutefishWindowBlur::CutefishWindowBlur(QObject *parent)
    : QObject(parent)
{
    if (auto *app = QCoreApplication::instance()) {
        connect(app, &QCoreApplication::aboutToQuit, this, &CutefishWindowBlur::cleanup);
    }
#if defined(Q_OS_LINUX)
    const QString platform = QGuiApplication::platformName();
    if (platform.startsWith(QLatin1String("wayland"), Qt::CaseInsensitive)) {
        m_isWayland = true;
        initWayland();
    } else if (platform.startsWith(QLatin1String("xcb"), Qt::CaseInsensitive)) {
        m_isX11 = true;
        initX11();
    }
#endif
}

CutefishWindowBlur::~CutefishWindowBlur()
{
#if defined(Q_OS_LINUX)
    if (QCoreApplication::instance()) {
        cleanup();
    } else {
        m_surfaceBlur = nullptr;
        m_registry = nullptr;
    }
#endif
}

void CutefishWindowBlur::cleanup()
{
#if defined(Q_OS_LINUX)
    if (m_surfaceBlur) {
        cutefish_surface_blur_v1_destroy(m_surfaceBlur);
        m_surfaceBlur = nullptr;
    }
    if (m_registry) {
        wl_registry_destroy(m_registry);
        m_registry = nullptr;
    }
    m_active = false;
#endif
}

CutefishWindowBlur *CutefishWindowBlur::instance()
{
    static CutefishWindowBlur s_instance;
    return &s_instance;
}

void CutefishWindowBlur::initWayland()
{
#if defined(Q_OS_LINUX)
    QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
    if (!native)
        return;

    auto *display = static_cast<struct wl_display *>(
        native->nativeResourceForIntegration("display"));
    if (!display)
        return;

    m_registry = wl_display_get_registry(display);
    if (!m_registry)
        return;

    wl_registry_add_listener(m_registry, &s_registryListener, this);
    wl_display_roundtrip(display);
#endif
}

void CutefishWindowBlur::initX11()
{
#if defined(Q_OS_LINUX) && defined(HAVE_XCB)
    m_active = true;
    emit activeChanged();
#endif
}

void CutefishWindowBlur::setWindow(QWindow *window)
{
    if (m_window == window)
        return;

    m_window = window;
    if (!m_window)
        return;

    connect(m_window, &QWindow::widthChanged, this, &CutefishWindowBlur::updateBlur);
    connect(m_window, &QWindow::heightChanged, this, &CutefishWindowBlur::updateBlur);
    connect(m_window, &QWindow::visibleChanged, this, [this] {
        if (m_window && m_window->isVisible()) {
            QTimer::singleShot(20, this, &CutefishWindowBlur::updateBlur);
            QTimer::singleShot(150, this, &CutefishWindowBlur::updateBlur);
        }
    });

    updateBlur();
}

void CutefishWindowBlur::updateBlur()
{
    if (!m_window || !m_window->isVisible())
        return;

    const int w = m_window->width();
    const int h = m_window->height();
    if (w <= 0 || h <= 0)
        return;

#if defined(Q_OS_LINUX)
    if (m_isWayland && m_surfaceBlur) {
        QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
        if (!native)
            return;

        auto *surface = static_cast<struct wl_surface *>(
            native->nativeResourceForWindow("surface", m_window));
        if (!surface)
            return;

        constexpr int kWindowRadius = 18;
        cutefish_surface_blur_v1_set(m_surfaceBlur, surface, 0, 0, w, h, kWindowRadius);
        wl_surface_commit(surface);

        auto *display = static_cast<struct wl_display *>(
            native->nativeResourceForIntegration("display"));
        if (display)
            wl_display_flush(display);
    }
#if defined(HAVE_XCB)
    else if (m_isX11) {
        QPlatformNativeInterface *native = QGuiApplication::platformNativeInterface();
        if (!native)
            return;

        auto *connection = static_cast<xcb_connection_t *>(
            native->nativeResourceForIntegration("connection"));
        if (!connection)
            return;

        const xcb_window_t winId = static_cast<xcb_window_t>(m_window->winId());
        if (!winId)
            return;

        const char atomName[] = "_KDE_NET_WM_BLUR_BEHIND_REGION";
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom(connection, 0, sizeof(atomName) - 1, atomName);
        xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(connection, cookie, nullptr);
        if (reply) {
            const uint32_t region[] = {0, 0, static_cast<uint32_t>(w), static_cast<uint32_t>(h)};
            xcb_change_property(connection, XCB_PROP_MODE_REPLACE, winId,
                                reply->atom, XCB_ATOM_CARDINAL, 32, 4, region);
            xcb_flush(connection);
            free(reply);
        }
    }
#endif
#endif
}
