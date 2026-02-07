#include "my_application.h"

#include <cstdlib>

int main(int argc, char** argv) {
  // Use native Wayland when available. Some environments (e.g. VS Code Snap)
  // force GDK_BACKEND=x11, routing through Xwayland. This causes rendering
  // freezes with NVIDIA GPUs on Wayland compositors due to Xwayland bugs.
  // Native Wayland avoids this issue entirely.
  if (getenv("WAYLAND_DISPLAY") != nullptr) {
    setenv("GDK_BACKEND", "wayland", /*overwrite=*/1);
    // Ensure system GSettings schemas are used (snap environments may provide
    // incomplete schemas that lack keys needed for the Wayland backend).
    setenv("GSETTINGS_SCHEMA_DIR", "/usr/share/glib-2.0/schemas", /*overwrite=*/1);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
