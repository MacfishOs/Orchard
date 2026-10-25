#!/usr/bin/env bash
set -euo pipefail

# Installs Orchard to the user's desktop environment (~/.local/share/orchard,
# ~/.local/bin, ~/.local/share/applications, ~/.local/share/icons).

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${1:-"$source_dir/build/release"}"

if [[ ! -f "$build_dir/orchard" ]]; then
  if [[ -f "$source_dir/build/dev/orchard" ]]; then
    build_dir="$source_dir/build/dev"
  else
    echo "Error: Could not find built orchard binary in $build_dir or build/dev." >&2
    echo "Please build Orchard first (e.g. meson compile -C build/release)" >&2
    exit 1
  fi
fi

prefix="${PREFIX:-"$HOME/.local"}"
install_root="$prefix/share/orchard"
bin_dir="$prefix/bin"
apps_dir="$prefix/share/applications"
icons_root="$prefix/share/icons/hicolor"
pixmaps_dir="$prefix/share/pixmaps"

echo "Installing Orchard from: $build_dir"
echo "Target directory:        $install_root"

mkdir -p "$install_root" "$bin_dir" "$apps_dir" "$pixmaps_dir"

# Copy binaries and shared libraries
for binary in orchard orchard-auth-helper orchard-adaptive-mix; do
  if [[ -f "$build_dir/$binary" ]]; then
    install -m 755 "$build_dir/$binary" "$install_root/$binary"
  fi
done

for lib in libdiscord_partner_sdk.so libLiteRt.so libwebgpu_dawn.so; do
  if [[ -f "$build_dir/$lib" ]]; then
    install -m 755 "$build_dir/$lib" "$install_root/$lib"
  fi
done

# Copy models
if [[ -d "$build_dir/models" ]]; then
  cp -a "$build_dir/models" "$install_root/"
elif [[ -d "$source_dir/models" ]]; then
  cp -a "$source_dir/models" "$install_root/"
fi

# Launcher wrapper in ~/.local/bin
cat > "$bin_dir/orchard" <<EOF
#!/usr/bin/env sh
exec "$install_root/orchard" "\$@"
EOF
chmod 755 "$bin_dir/orchard"

# Desktop entry
cat > "$apps_dir/orchard.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Orchard
GenericName=Music Player
Comment=Your YouTube Music library, with more control over how you listen
Exec=$install_root/orchard %U
Icon=orchard
Terminal=false
MimeType=x-scheme-handler/orchard;
Categories=AudioVideo;Audio;Player;
StartupWMClass=orchard
Keywords=music;player;youtube;streaming;audio;
EOF

# Install icons in standard hicolor sizes
logo_src="$source_dir/app/qml/assets/orchard-logo.png"
if [[ -f "$logo_src" ]]; then
  mkdir -p "$icons_root/512x512/apps"
  cp "$logo_src" "$icons_root/512x512/apps/orchard.png"
  cp "$logo_src" "$pixmaps_dir/orchard.png"

  for size in 256 128 64 48 32 16; do
    target_dir="$icons_root/${size}x${size}/apps"
    mkdir -p "$target_dir"
    if command -v magick >/dev/null 2>&1; then
      magick "$logo_src" -resize "${size}x${size}" "$target_dir/orchard.png"
    elif command -v convert >/dev/null 2>&1; then
      convert "$logo_src" -resize "${size}x${size}" "$target_dir/orchard.png"
    elif command -v ffmpeg >/dev/null 2>&1; then
      ffmpeg -y -v error -i "$logo_src" -vf "scale=${size}:${size}" "$target_dir/orchard.png"
    fi
  done
fi

# Refresh caches if tools are available
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$apps_dir" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$icons_root" 2>/dev/null || true
fi

if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default orchard.desktop x-scheme-handler/orchard 2>/dev/null || true
fi

echo "Orchard has been successfully installed!"
echo "Run 'orchard' or launch Orchard from your application menu."
