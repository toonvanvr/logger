#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#if __has_include(<libayatana-appindicator/app-indicator.h>)
#include <libayatana-appindicator/app-indicator.h>
#elif __has_include(<libappindicator/app-indicator.h>)
#include <libappindicator/app-indicator.h>
#else
#error "AppIndicator headers not found (install libayatana-appindicator3-dev or libappindicator3-dev)."
#endif

#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr const char* kTrayChannelName = "com.logger/tray";

constexpr const char* kTrayActionWindowToggle = "window.toggle";
constexpr const char* kTrayActionConnectionDocs = "connection.docs";
constexpr const char* kTrayActionConnectionHttpBase = "connection.http_base";
constexpr const char* kTrayActionConnectionHttpEvents = "connection.http_events";
constexpr const char* kTrayActionConnectionHttpData = "connection.http_data";
constexpr const char* kTrayActionConnectionWsViewer = "connection.ws_viewer";
constexpr const char* kTrayActionConnectionUdpIngest = "connection.udp_ingest";
constexpr const char* kTrayActionConnectionTcpIngest = "connection.tcp_ingest";

constexpr const char* kTrayActionExtensionsLoki = "extensions.loki";
constexpr const char* kTrayActionExtensionsGrafana = "extensions.grafana";

constexpr const char* kTrayActionClearStore = "store.clear";
constexpr const char* kTrayActionQuit = "app.quit";

struct TrayActionData {
  MyApplication* app;
  gchar* id;
};

TrayActionData* tray_action_data_new(MyApplication* app, const gchar* id) {
  TrayActionData* data = g_new0(TrayActionData, 1);
  data->app = app;
  data->id = g_strdup(id);
  return data;
}

void tray_action_data_free(gpointer user_data, GClosure* /*closure*/) {
  TrayActionData* data = static_cast<TrayActionData*>(user_data);
  if (data == nullptr) {
    return;
  }
  g_clear_pointer(&data->id, g_free);
  g_free(data);
}

}  // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;

  GtkWindow* window;

  FlMethodChannel* tray_channel;
  AppIndicator* tray_indicator;
  GtkWidget* tray_menu;
  GHashTable* tray_items_by_id;

  GtkWidget* tray_show_hide_item;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));

  if (self->tray_show_hide_item != nullptr && self->window != nullptr) {
    const bool visible = gtk_widget_get_visible(GTK_WIDGET(self->window));
    gtk_menu_item_set_label(GTK_MENU_ITEM(self->tray_show_hide_item),
                            visible ? "Hide logger" : "Show logger");
  }
}

static void tray_register_item(MyApplication* self,
                               const gchar* id,
                               GtkWidget* item) {
  if (self->tray_items_by_id == nullptr) {
    return;
  }

  g_hash_table_insert(self->tray_items_by_id, g_strdup(id), g_object_ref(item));
}

static GtkWidget* tray_lookup_item(MyApplication* self, const gchar* id) {
  if (self->tray_items_by_id == nullptr) {
    return nullptr;
  }
  return static_cast<GtkWidget*>(g_hash_table_lookup(self->tray_items_by_id, id));
}

static void tray_invoke_on_action(MyApplication* self,
                                  const gchar* id,
                                  bool has_checked,
                                  bool checked) {
  if (self->tray_channel == nullptr) {
    return;
  }

  g_autoptr(FlValue) args = fl_value_new_map();
  fl_value_set_string_take(args, "id", fl_value_new_string(id));
  if (has_checked) {
    fl_value_set_string_take(args, "checked", fl_value_new_bool(checked));
  }

  fl_method_channel_invoke_method(self->tray_channel, "onAction", args, nullptr,
                                  nullptr, nullptr);
}

static void tray_update_show_hide_label(MyApplication* self) {
  if (self->tray_show_hide_item == nullptr || self->window == nullptr) {
    return;
  }

  const bool visible = gtk_widget_get_visible(GTK_WIDGET(self->window));
  gtk_menu_item_set_label(GTK_MENU_ITEM(self->tray_show_hide_item),
                          visible ? "Hide logger" : "Show logger");
}

static void tray_toggle_window(MyApplication* self) {
  if (self->window == nullptr) {
    return;
  }

  if (gtk_widget_get_visible(GTK_WIDGET(self->window))) {
    gtk_widget_hide(GTK_WIDGET(self->window));
  } else {
    gtk_widget_show(GTK_WIDGET(self->window));
    gtk_window_present(self->window);
  }

  tray_update_show_hide_label(self);
}

static void tray_show_hide_activate_cb(GtkMenuItem* /*menu_item*/, gpointer user_data) {
  tray_toggle_window(MY_APPLICATION(user_data));
}

static void tray_quit_activate_cb(GtkMenuItem* /*menu_item*/, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  tray_invoke_on_action(self, kTrayActionQuit, false, false);
  g_application_quit(G_APPLICATION(self));
}

static void tray_action_activate_cb(GtkMenuItem* /*menu_item*/, gpointer user_data) {
  TrayActionData* data = static_cast<TrayActionData*>(user_data);
  tray_invoke_on_action(data->app, data->id, false, false);
}

static void tray_check_toggled_cb(GtkCheckMenuItem* menu_item, gpointer user_data) {
  if (GPOINTER_TO_INT(g_object_get_data(G_OBJECT(menu_item), "logger-suppress")) != 0) {
    return;
  }

  TrayActionData* data = static_cast<TrayActionData*>(user_data);
  const bool checked = gtk_check_menu_item_get_active(menu_item);
  tray_invoke_on_action(data->app, data->id, true, checked);
}

static void tray_method_call_handler(FlMethodChannel* /*channel*/,
                                     FlMethodCall* method_call,
                                     gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  auto respond_success = [&]() {
    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, nullptr);
  };

  auto respond_error = [&](const gchar* code, const gchar* message) {
    g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(
        fl_method_error_response_new(code, message, fl_value_new_null()));
    fl_method_call_respond(method_call, response, nullptr);
  };

  if (g_strcmp0(method, "setLabel") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      respond_error("bad_args", "Expected map arguments");
      return;
    }
    FlValue* id_value = fl_value_lookup_string(args, "id");
    FlValue* label_value = fl_value_lookup_string(args, "label");
    if (id_value == nullptr || fl_value_get_type(id_value) != FL_VALUE_TYPE_STRING ||
        label_value == nullptr || fl_value_get_type(label_value) != FL_VALUE_TYPE_STRING) {
      respond_error("bad_args", "Expected {id: string, label: string}");
      return;
    }

    const gchar* id = fl_value_get_string(id_value);
    const gchar* label = fl_value_get_string(label_value);
    GtkWidget* item = tray_lookup_item(self, id);
    if (item == nullptr) {
      g_warning("Tray setLabel ignored; unknown id: %s", id);
      respond_success();
      return;
    }

    gtk_menu_item_set_label(GTK_MENU_ITEM(item), label);
    respond_success();
    return;
  }

  if (g_strcmp0(method, "setEnabled") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      respond_error("bad_args", "Expected map arguments");
      return;
    }
    FlValue* id_value = fl_value_lookup_string(args, "id");
    FlValue* enabled_value = fl_value_lookup_string(args, "enabled");
    if (id_value == nullptr || fl_value_get_type(id_value) != FL_VALUE_TYPE_STRING ||
        enabled_value == nullptr || fl_value_get_type(enabled_value) != FL_VALUE_TYPE_BOOL) {
      respond_error("bad_args", "Expected {id: string, enabled: bool}");
      return;
    }

    const gchar* id = fl_value_get_string(id_value);
    const bool enabled = fl_value_get_bool(enabled_value);
    GtkWidget* item = tray_lookup_item(self, id);
    if (item == nullptr) {
      g_warning("Tray setEnabled ignored; unknown id: %s", id);
      respond_success();
      return;
    }

    gtk_widget_set_sensitive(item, enabled);
    respond_success();
    return;
  }

  if (g_strcmp0(method, "setChecked") == 0) {
    if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
      respond_error("bad_args", "Expected map arguments");
      return;
    }
    FlValue* id_value = fl_value_lookup_string(args, "id");
    FlValue* checked_value = fl_value_lookup_string(args, "checked");
    if (id_value == nullptr || fl_value_get_type(id_value) != FL_VALUE_TYPE_STRING ||
        checked_value == nullptr || fl_value_get_type(checked_value) != FL_VALUE_TYPE_BOOL) {
      respond_error("bad_args", "Expected {id: string, checked: bool}");
      return;
    }

    const gchar* id = fl_value_get_string(id_value);
    const bool checked = fl_value_get_bool(checked_value);
    GtkWidget* item = tray_lookup_item(self, id);
    if (item == nullptr) {
      g_warning("Tray setChecked ignored; unknown id: %s", id);
      respond_success();
      return;
    }
    if (!GTK_IS_CHECK_MENU_ITEM(item)) {
      g_warning("Tray setChecked ignored; id is not check item: %s", id);
      respond_success();
      return;
    }

    g_object_set_data(G_OBJECT(item), "logger-suppress", GINT_TO_POINTER(1));
    gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(item), checked);
    g_object_set_data(G_OBJECT(item), "logger-suppress", GINT_TO_POINTER(0));

    respond_success();
    return;
  }

  fl_method_call_respond_not_implemented(method_call, nullptr);
}

static void tray_init(MyApplication* self, FlView* view) {
  if (self->tray_indicator != nullptr) {
    return;
  }

  self->tray_items_by_id = g_hash_table_new_full(
      g_str_hash, g_str_equal, g_free, reinterpret_cast<GDestroyNotify>(g_object_unref));

  // Create the method channel used to signal actions and receive updates.
  g_autoptr(FlStandardMethodCodec) tray_codec = fl_standard_method_codec_new();
  self->tray_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)), kTrayChannelName,
      FL_METHOD_CODEC(tray_codec));
  fl_method_channel_set_method_call_handler(self->tray_channel,
                                            tray_method_call_handler, self,
                                            nullptr);

  // Build tray menu.
  self->tray_menu = gtk_menu_new();

  // 1) Show/hide logger
  self->tray_show_hide_item = gtk_menu_item_new_with_label("Show logger");
  g_signal_connect(self->tray_show_hide_item, "activate",
                   G_CALLBACK(tray_show_hide_activate_cb), self);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), self->tray_show_hide_item);
  tray_register_item(self, kTrayActionWindowToggle, self->tray_show_hide_item);

  // separator
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), gtk_separator_menu_item_new());

  // 2) Connection ▶
  GtkWidget* connection_item = gtk_menu_item_new_with_label("Connection");
  GtkWidget* connection_menu = gtk_menu_new();
  gtk_menu_item_set_submenu(GTK_MENU_ITEM(connection_item), connection_menu);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), connection_item);

  {
    GtkWidget* docs_item = gtk_menu_item_new_with_label("Official documentation");
    g_signal_connect_data(docs_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionDocs),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), docs_item);
    tray_register_item(self, kTrayActionConnectionDocs, docs_item);

    GtkWidget* http_base_item = gtk_menu_item_new_with_label("HTTP — http://127.0.0.1:{PORT}");
    g_signal_connect_data(http_base_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionHttpBase),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), http_base_item);
    tray_register_item(self, kTrayActionConnectionHttpBase, http_base_item);

    GtkWidget* http_events_item = gtk_menu_item_new_with_label("HTTP Events — /api/v2/events");
    g_signal_connect_data(http_events_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionHttpEvents),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), http_events_item);
    tray_register_item(self, kTrayActionConnectionHttpEvents, http_events_item);

    GtkWidget* http_data_item = gtk_menu_item_new_with_label("HTTP Data — /api/v2/data");
    g_signal_connect_data(http_data_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionHttpData),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), http_data_item);
    tray_register_item(self, kTrayActionConnectionHttpData, http_data_item);

    GtkWidget* ws_viewer_item = gtk_menu_item_new_with_label("WebSocket Viewer — /api/v2/stream");
    g_signal_connect_data(ws_viewer_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionWsViewer),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), ws_viewer_item);
    tray_register_item(self, kTrayActionConnectionWsViewer, ws_viewer_item);

    GtkWidget* udp_item = gtk_menu_item_new_with_label("UDP ingest — udp://127.0.0.1:{UDP_PORT}");
    g_signal_connect_data(udp_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionUdpIngest),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), udp_item);
    tray_register_item(self, kTrayActionConnectionUdpIngest, udp_item);

    GtkWidget* tcp_item = gtk_menu_item_new_with_label("TCP ingest — tcp://127.0.0.1:{TCP_PORT}");
    g_signal_connect_data(tcp_item, "activate", G_CALLBACK(tray_action_activate_cb),
                          tray_action_data_new(self, kTrayActionConnectionTcpIngest),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(connection_menu), tcp_item);
    tray_register_item(self, kTrayActionConnectionTcpIngest, tcp_item);
  }

  // separator
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), gtk_separator_menu_item_new());

  // 3) Extensions ▶
  GtkWidget* extensions_item = gtk_menu_item_new_with_label("Extensions");
  GtkWidget* extensions_menu = gtk_menu_new();
  gtk_menu_item_set_submenu(GTK_MENU_ITEM(extensions_item), extensions_menu);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), extensions_item);

  {
    GtkWidget* loki_item = gtk_check_menu_item_new_with_label("Loki");
    g_signal_connect_data(loki_item, "toggled", G_CALLBACK(tray_check_toggled_cb),
                          tray_action_data_new(self, kTrayActionExtensionsLoki),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(extensions_menu), loki_item);
    tray_register_item(self, kTrayActionExtensionsLoki, loki_item);

    GtkWidget* grafana_item = gtk_check_menu_item_new_with_label("Grafana");
    gtk_widget_set_sensitive(grafana_item, FALSE);
    g_signal_connect_data(grafana_item, "toggled", G_CALLBACK(tray_check_toggled_cb),
                          tray_action_data_new(self, kTrayActionExtensionsGrafana),
                          tray_action_data_free, static_cast<GConnectFlags>(0));
    gtk_menu_shell_append(GTK_MENU_SHELL(extensions_menu), grafana_item);
    tray_register_item(self, kTrayActionExtensionsGrafana, grafana_item);
  }

  // separator
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), gtk_separator_menu_item_new());

  // Clear store
  GtkWidget* clear_store_item = gtk_menu_item_new_with_label("Clear store");
  g_signal_connect_data(clear_store_item, "activate", G_CALLBACK(tray_action_activate_cb),
                        tray_action_data_new(self, kTrayActionClearStore),
                        tray_action_data_free, static_cast<GConnectFlags>(0));
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), clear_store_item);
  tray_register_item(self, kTrayActionClearStore, clear_store_item);

  // Quit
  GtkWidget* quit_item = gtk_menu_item_new_with_label("Quit");
  g_signal_connect(quit_item, "activate", G_CALLBACK(tray_quit_activate_cb), self);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), quit_item);
  tray_register_item(self, kTrayActionQuit, quit_item);

  gtk_widget_show_all(self->tray_menu);

  // Create indicator.
  self->tray_indicator = app_indicator_new("logger-tray", "app",
                                           APP_INDICATOR_CATEGORY_APPLICATION_STATUS);

  // Prefer an absolute icon path from the bundled data directory (same icon as the window).
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path != nullptr) {
    g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
    g_autofree gchar* icon_path = g_build_filename(exe_dir, "data", "app_icon.png", nullptr);
    if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
      app_indicator_set_icon_full(self->tray_indicator, icon_path, "Logger");
    }
  }

  app_indicator_set_status(self->tray_indicator, APP_INDICATOR_STATUS_ACTIVE);
  app_indicator_set_menu(self->tray_indicator, GTK_MENU(self->tray_menu));

  tray_update_show_hide_label(self);
}

// Method channel handler for com.logger/window.
static void window_method_call_handler(FlMethodChannel* channel,
                                       FlMethodCall* method_call,
                                       gpointer user_data) {
  GtkWindow* window = GTK_WINDOW(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (g_strcmp0(method, "setAlwaysOnTop") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gboolean value = fl_value_get_bool(args);
    // Fetch active window at call time to ensure valid pointer (T15 fix).
    GtkWindow* active = GTK_WINDOW(gtk_application_get_active_window(
        GTK_APPLICATION(g_application_get_default())));
    gtk_window_set_keep_above(active != NULL ? active : window, value);

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "minimize") == 0) {
    gtk_window_iconify(window);

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "maximize") == 0) {
    if (gtk_window_is_maximized(window)) {
      gtk_window_unmaximize(window);
    } else {
      gtk_window_maximize(window);
    }

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "close") == 0) {
    gtk_window_close(window);

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "isMaximized") == 0) {
    gboolean maximized = gtk_window_is_maximized(window);

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(maximized)));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "setDecorated") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    gboolean value = fl_value_get_bool(args);
    GtkWidget* titlebar = gtk_window_get_titlebar(window);
    if (titlebar != NULL) {
      gtk_widget_set_visible(titlebar, value);
    } else {
      gtk_window_set_decorated(window, value);
    }

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else if (g_strcmp0(method, "startDrag") == 0) {
    GdkWindow* gdk_window = gtk_widget_get_window(GTK_WIDGET(window));
    GdkDisplay* display = gdk_window_get_display(gdk_window);
    GdkSeat* seat = gdk_display_get_default_seat(display);
    GdkDevice* device = gdk_seat_get_pointer(seat);
    gint x, y;
    gdk_device_get_position(device, NULL, &x, &y);
    gtk_window_begin_move_drag(window, 1, x, y, gtk_get_current_event_time());

    g_autoptr(FlMethodResponse) response =
        FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
    fl_method_call_respond(method_call, response, NULL);
  } else {
    fl_method_call_respond_not_implemented(method_call, NULL);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkDisplay* display = gdk_display_get_default();
  if (GDK_IS_X11_DISPLAY(display)) {
    GdkScreen* screen = gtk_window_get_screen(window);
    if (GDK_IS_X11_SCREEN(screen)) {
      const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
      if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
        use_header_bar = FALSE;
      }
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "app");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "app");
  }

  gtk_window_set_default_size(window, 1280, 720);

  // Set application icon from bundle data directory.
  {
    g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", NULL);
    if (exe_path != NULL) {
      g_autofree gchar* exe_dir = g_path_get_dirname(exe_path);
      g_autofree gchar* icon_path = g_build_filename(exe_dir, "data", "app_icon.png", NULL);
      g_autoptr(GdkPixbuf) icon = gdk_pixbuf_new_from_file(icon_path, NULL);
      if (icon != NULL) {
        gtk_window_set_icon(window, icon);
      }
    }
  }

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  // Register window method channel for always-on-top support.
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* window_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.logger/window", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      window_channel, window_method_call_handler, window, NULL);

    // Register tray method channel + tray icon/menu.
    tray_init(self, view);

  // Register URI method channel for logger:// deep-link forwarding.
  g_autoptr(FlStandardMethodCodec) uri_codec = fl_standard_method_codec_new();
  FlMethodChannel* uri_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "com.logger/uri", FL_METHOD_CODEC(uri_codec));

  // Forward any logger:// URIs from command-line arguments to Dart.
  if (self->dart_entrypoint_arguments != NULL) {
    for (gint i = 0; self->dart_entrypoint_arguments[i] != NULL; i++) {
      if (g_str_has_prefix(self->dart_entrypoint_arguments[i], "logger://")) {
        g_autoptr(FlValue) uri_value =
            fl_value_new_string(self->dart_entrypoint_arguments[i]);
        fl_method_channel_invoke_method(uri_channel, "handleUri", uri_value,
                                        NULL, NULL, NULL);
        break;
      }
    }
  }

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);

  g_clear_object(&self->tray_channel);
  g_clear_object(&self->tray_indicator);
  g_clear_pointer(&self->tray_items_by_id, g_hash_table_unref);
  self->tray_menu = nullptr;
  self->tray_show_hide_item = nullptr;
  self->window = nullptr;

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
