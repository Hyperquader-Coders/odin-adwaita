#+test
package adwaita

import "core:testing"

import glib "glib:glib"
import gobj "glib:gobject"

@(private = "file")
criticals: int

@(private = "file")
count_critical :: proc "c" (domain: cstring, level: glib.LogLevelFlags, message: cstring, data: rawptr) {
    criticals += 1
}

@(test)
test_casts_and_checks_on_an_instance :: proc(t: ^testing.T) {
    toast := toast_new("title")
    defer gobj.object_unref(rawptr(toast))
    testing.expect(t, TOAST(toast) == toast)
    testing.expect(t, bool(IS_TOAST(toast)))
    testing.expect(t, !bool(IS_ALERT_DIALOG(toast)))
    testing.expect(t, !bool(IS_DIALOG(toast)))
}

@(test)
test_wrong_cast_is_reported :: proc(t: ^testing.T) {
    when gobj.GTK_SAFE_CAST {
        toast := toast_new("title")
        defer gobj.object_unref(rawptr(toast))
        criticals = 0
        id := glib.log_set_handler("GLib-GObject", {.LOG_LEVEL_CRITICAL}, count_critical, nil)
        _ = ALERT_DIALOG(toast)
        glib.log_remove_handler("GLib-GObject", id)
        testing.expect_value(t, criticals, 1)
        criticals = 0
        _ = TOAST(toast)
        testing.expect_value(t, criticals, 0)
    }
}
