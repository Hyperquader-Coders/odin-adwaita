# odin-adwaita cheat sheet

One screen per job: the calls a program makes, in the order it makes them, and the few rules
worth remembering. Every `adw.` name here is a public declaration in [API.md](API.md), and
`make lint` fails when one is not. libadwaita's own documentation is the reference; this is the
idiom layer over the generated names. GTK itself (windows, boxes, labels, entries) is odin-gtk4,
imported as `gtk "gtk4:gtk4"`.

Conventions that hold everywhere: `import adw "adwaita:adwaita"` beside `glib:glib`,
`glib:gio`, `glib:gobject` and `gtk4:gtk4` ([Use](../README.md#use)); a procedure is the C name
without `adw_`, a type the C name without `Adw`; a `boolean` is `glib.boolean`. Every class has a
cast, such as `adw.ALERT_DIALOG(w)`, and a test, such as `adw.IS_ALERT_DIALOG(w)` ([DECISIONS §6](DECISIONS.md#6-gobject-casts-are-generated-alert_dialogw-is_alert_dialogw)):
a constructor returns the base type (`^gtk.Widget`, or `^adw.Dialog` for a dialog), and you cast
to the class whose procedures you call next. A callback is a `proc "c"`: its first line is
`context = app_ctx`, the `runtime.Context` saved at startup.

## adw:Application — the app, its window and its toasts

```odin
import "glib:gio"
import "glib:glib"
import "glib:gobject"
import gtk "gtk4:gtk4"
import adw "adwaita:adwaita"

app := adw.application_new("org.example.App", {})        // runs adw.init as part of its startup
gobject.signal_connect(app, "activate", on_activate, nil)
status := gio.application_run(gio.APPLICATION(app), os.args)
gobject.object_unref(app)

on_activate :: proc "c" (app: ^adw.Application, data: glib.pointer) {
	context = app_ctx
	widget := adw.application_window_new(gtk.APPLICATION(app))   // ^gtk.Widget
	gtk.window_set_title(gtk.WINDOW(widget), "Example")
	gtk.window_set_default_size(gtk.WINDOW(widget), 900, 640)

	toolbars := adw.toolbar_view_new()
	bar := adw.header_bar_new()
	adw.header_bar_pack_end(adw.HEADER_BAR(bar), menu_button)
	adw.header_bar_set_title_widget(adw.HEADER_BAR(bar), adw.window_title_new("Example", "subtitle"))
	adw.toolbar_view_add_top_bar(adw.TOOLBAR_VIEW(toolbars), bar)
	adw.toolbar_view_set_content(adw.TOOLBAR_VIEW(toolbars), content)

	toaster := adw.toast_overlay_new()
	adw.toast_overlay_set_child(adw.TOAST_OVERLAY(toaster), toolbars)
	adw.application_window_set_content(adw.APPLICATION_WINDOW(widget), toaster)
	gtk.window_present(gtk.WINDOW(widget))

	toast := adw.toast_new("Saved")                      // the overlay owns it once added
	adw.toast_set_timeout(toast, 3)
	adw.toast_overlay_add_toast(adw.TOAST_OVERLAY(toaster), toast)
}

adw.style_manager_set_color_scheme(adw.style_manager_get_default(), .PREFER_DARK)   // .DEFAULT follows the system
dark := adw.style_manager_get_dark(adw.style_manager_get_default())
```

| remember | |
|---|---|
| Create an `adw.Application`, not a `gtk.Application`, for any program that shows an `AdwDialog` | `adw.application_new` runs `adw.init` as part of its own startup, which an `AdwDialog` needs; a program on a plain GTK app calls `adw.init()` itself |
| `application_new` returns `^adw.Application`, which derives from `gtk.Application` | pass it to a GTK parameter as `gtk.APPLICATION(app)` ([DECISIONS §5](DECISIONS.md#5-gapplication-and-gtkapplication-collide)) |
| A window holds one child, set with `application_window_set_content` | put a `toolbar_view` in it, then the header bar and the content in that |
| A new toast is the overlay's | to keep a handle past `toast_overlay_add_toast`, `gobject.object_ref` it and unref on its `"dismissed"` |
| Flag sets are `bit_set`s ([PATCHED.md](PATCHED.md)) | `adw.TabViewShortcuts` is one: `{.TAB_VIEW_SHORTCUT_CONTROL_TAB}` |

## adw:Dialog — a sheet, a question, an about box

```odin
import "glib:glib"
import "glib:gobject"
import gtk "gtk4:gtk4"
import adw "adwaita:adwaita"

d := adw.dialog_new()                                    // a free-form sheet
adw.dialog_set_title(d, "Rename")
adw.dialog_set_content_width(d, 420)
row := adw.entry_row_new()
adw.dialog_set_child(d, row)
adw.dialog_set_default_widget(d, ok_button)
adw.dialog_present(d, parent)                            // a ^gtk.Widget inside the window; it is the dialog's
adw.dialog_close(d)                                      // may be refused; adw.dialog_force_close always closes

dialog := adw.alert_dialog_new("Delete file?", "It cannot be undone.")   // ^adw.Dialog
q := adw.ALERT_DIALOG(dialog)
adw.alert_dialog_add_response(q, "cancel", "_Cancel")
adw.alert_dialog_add_response(q, "delete", "_Delete")
adw.alert_dialog_set_response_appearance(q, "delete", .RESPONSE_DESTRUCTIVE)   // .RESPONSE_SUGGESTED
adw.alert_dialog_set_default_response(q, "cancel")
adw.alert_dialog_set_close_response(q, "cancel")         // what Esc answers
gobject.signal_connect(q, "response", on_response, nil)
adw.dialog_present(adw.DIALOG(q), parent)

on_response :: proc "c" (q: ^adw.AlertDialog, response: cstring, data: glib.pointer) {
	context = app_ctx
	if string(response) == "delete" { /* … */ }
}

about := adw.about_dialog_new()
adw.about_dialog_set_application_name(adw.ABOUT_DIALOG(about), "Example")
adw.about_dialog_set_version(adw.ABOUT_DIALOG(about), "1.0")
adw.about_dialog_set_license_type(adw.ABOUT_DIALOG(about), .GPL_3_0)
adw.dialog_present(about, parent)
```

| remember | |
|---|---|
| `alert_dialog_new`, `about_dialog_new`, `preferences_dialog_new` return `^adw.Dialog` | cast with `adw.ALERT_DIALOG(d)` for the class's own procedures, `adw.DIALOG(q)` back for the shared ones |
| Answer an alert from `"response"` (the id you gave `add_response`), with `"destroy"` for no answer | `alert_dialog_choose` never finishes when an Esc closes a dialog sheeted in its own window (libadwaita 1.5) |
| `dialog_present` takes a widget, not a window | pass any widget inside the window; the dialog finds the window |
| A dialog may outlive the window that asked | close it from the window's teardown with `dialog_force_close` |

## adw:TabView — tabs, the bar and the overview

```odin
import "glib:glib"
import "glib:gobject"
import gtk "gtk4:gtk4"
import adw "adwaita:adwaita"

view := adw.tab_view_new()                               // ^adw.TabView
bar := adw.tab_bar_new()                                 // ^adw.TabBar
adw.tab_bar_set_view(bar, view)
adw.tab_bar_set_autohide(bar, false)

page := adw.tab_view_append(view, child)                 // ^adw.TabPage, owned by the view
adw.tab_page_set_title(page, "shell")
adw.tab_page_set_loading(page, true)
adw.tab_page_set_needs_attention(page, true)
adw.tab_view_set_selected_page(view, page)
adw.tab_view_set_page_pinned(view, page, true)
current := adw.tab_view_get_selected_page(view)
n := adw.tab_view_get_n_pages(view)
first := adw.tab_view_get_nth_page(view, 0)

gobject.signal_connect(view, "close-page", on_close_page, nil)
adw.tab_view_close_page(view, page)                      // asks "close-page" first

on_close_page :: proc "c" (view: ^adw.TabView, page: ^adw.TabPage, data: glib.pointer) -> glib.boolean {
	context = app_ctx
	adw.tab_view_close_page_finish(view, page, true)     // true closes it, false keeps it
	return true                                          // handled: the view does nothing more
}

overview := adw.tab_overview_new()                       // ^gtk.Widget
adw.tab_overview_set_view(adw.TAB_OVERVIEW(overview), view)
adw.tab_overview_set_child(adw.TAB_OVERVIEW(overview), content)
adw.tab_overview_set_enable_new_tab(adw.TAB_OVERVIEW(overview), true)
adw.tab_overview_set_open(adw.TAB_OVERVIEW(overview), true)
```

| remember | |
|---|---|
| A `"close-page"` handler must call `close_page_finish` for every page it handles, now or later | returning `true` without it leaves the page waiting for an answer |
| The `TabView` holds the pages' content and must itself sit in the window | the bar, the overview and the tab button only show it: each takes it with `set_view` |
| The view finalizes with its tree, before the window's `"destroy"` | take a `gobject.object_ref` if a handler disconnects from it in teardown |
| The page is the tab; its content is `adw.tab_page_get_child(page)` | `adw.tab_view_get_page(view, child)` goes the other way |
| `tab_page_set_icon` takes a `^gio.Icon` | a themed icon is `gio.themed_icon_new(name)` |

## adw:Rows — settings and lists

```odin
import "glib:gio"
import gtk "gtk4:gtk4"
import adw "adwaita:adwaita"

page := adw.preferences_page_new()
group := adw.preferences_group_new()
adw.preferences_group_set_title(adw.PREFERENCES_GROUP(group), "Network")
adw.preferences_group_set_description(adw.PREFERENCES_GROUP(group), "How requests are made")

row := adw.action_row_new()
adw.preferences_row_set_title(adw.PREFERENCES_ROW(row), "Proxy")      // the title lives on PreferencesRow
adw.action_row_set_subtitle(adw.ACTION_ROW(row), "http://p:3128")
adw.action_row_add_suffix(adw.ACTION_ROW(row), gtk.switch_new())
adw.preferences_group_add(adw.PREFERENCES_GROUP(group), row)

toggle := adw.switch_row_new()
adw.switch_row_set_active(adw.SWITCH_ROW(toggle), true)
entry := adw.entry_row_new()
adw.entry_row_set_activates_default(adw.ENTRY_ROW(entry), true)
text := gtk.editable_get_text(gtk.EDITABLE(entry))                    // an EntryRow is a GtkEditable

adw.preferences_page_add(adw.PREFERENCES_PAGE(page), adw.PREFERENCES_GROUP(group))
dialog := adw.preferences_dialog_new()
adw.preferences_dialog_add(adw.PREFERENCES_DIALOG(dialog), adw.PREFERENCES_PAGE(page))

stack := adw.view_stack_new()
adw.view_stack_add_titled_with_icon(adw.VIEW_STACK(stack), child, "files", "Files", "folder-symbolic")
adw.view_stack_set_visible_child_name(adw.VIEW_STACK(stack), "files")
clamp := adw.clamp_new()                                              // keeps content a readable width
adw.clamp_set_maximum_size(adw.CLAMP(clamp), 640)
adw.clamp_set_child(adw.CLAMP(clamp), stack)
```

| remember | |
|---|---|
| A row's title is `preferences_row_set_title`, its subtitle `action_row_set_subtitle` | `ActionRow` derives from `PreferencesRow`, so `adw.PREFERENCES_ROW(row)` is the cast |
| Most constructors return `^gtk.Widget`; `tab_view_new`, `tab_bar_new`, `toast_new` and `navigation_page_new` return their own class | cast before a class procedure; a wrong cast logs a critical unless built with `-o:speed` |
| A parameter wants the class (`^adw.PreferencesGroup`) and the group you hold is a `^gtk.Widget` | `adw.PREFERENCES_GROUP(group)` |
| `adw.bin_set_child` takes the `Bin` type, `adw.clamp_set_child` the `Clamp` | the cast goes on the container, never the child |
