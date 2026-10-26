/*
 * Copyright (C) 2026 Cutefish / Orchard
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#pragma once

#include <QObject>
#include <QPointer>
#include <QWindow>

struct cutefish_surface_blur_v1;
struct wl_registry;

class CutefishWindowBlur final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ isActive NOTIFY activeChanged)

public:
    static CutefishWindowBlur *instance();

    void setWindow(QWindow *window);
    [[nodiscard]] bool isActive() const { return m_active; }

public slots:
    void updateBlur();
    void cleanup();

signals:
    void activeChanged();

private:
    explicit CutefishWindowBlur(QObject *parent = nullptr);
    ~CutefishWindowBlur() override;

    void initWayland();
    void initX11();

    QPointer<QWindow> m_window;
    cutefish_surface_blur_v1 *m_surfaceBlur{nullptr};
    wl_registry *m_registry{nullptr};
    bool m_active{false};
    bool m_isWayland{false};
    bool m_isX11{false};

    friend void cutefishRegistryHandler(void *data, struct wl_registry *registry,
                                       uint32_t name, const char *interface, uint32_t version);
    friend void cutefishRegistryRemove(void *data, struct wl_registry *registry, uint32_t name);
};
