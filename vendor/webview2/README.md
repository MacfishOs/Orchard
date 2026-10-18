# WebView2 SDK 1.0.4258.31

From the `Microsoft.Web.WebView2` 1.0.4258.31 NuGet package
(SHA-256 `56f7f4b8bf9aee4b8efefbbdd4f67d5f74ebd1b100ed0806da71bf76af481aa9`):

- `include/WebView2.h`, `include/WebView2EnvironmentOptions.h` (`build/native/include`)
- `lib/x64/WebView2Loader.dll`, `lib/arm64/WebView2Loader.dll` (`build/native/<arch>`)

The Windows auth helper loads `WebView2Loader.dll` from its own directory at runtime,
so no import library is needed. The browser itself is the installed Microsoft Edge
WebView2 Runtime. License: `LICENSE.txt` (BSD-3-Clause).
