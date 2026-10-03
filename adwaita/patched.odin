package adwaita

import gio "glib:gio"
import gobj "glib:gobject"
import gtk "gtk4:gtk4"
import pango "pango:pango"

// Typed pins for the post-generation rules (docs/PATCHED.md). A regeneration that drops one
// fails to compile here.

// gchar * is cstring, not ^char.
@(private = "file")
patched_breakpoint_condition_to_string: proc "c" (_: ^BreakpointCondition) -> cstring = breakpoint_condition_to_string

@(private = "file")
patched_alert_dialog_choose_finish: proc "c" (_: ^AlertDialog, _: ^gio.AsyncResult) -> cstring = alert_dialog_choose_finish

// `typedef struct _AdwFoo AdwFoo` is one type, Foo, not an alias of _AdwFoo.
@(private = "file")
patched_application_new: proc "c" (_: cstring, _: gio.ApplicationFlags) -> ^Application = application_new

// TYPE_FOO is the get_type procedure itself.
@(private = "file")
patched_type_dialog: proc "c" () -> gobj.Type = TYPE_DIALOG

// DURATION_INFINITE is the guint value 0xffffffff.
@(private = "file")
patched_duration_infinite: u32 = DURATION_INFINITE

// GApplication and GtkApplication trim to the same name; AdwApplication derives from GtkApplication.
#assert(type_of(Application{}.parent_instance) == gtk.Application)
#assert(type_of(ApplicationClass{}.parent_class) == gtk.ApplicationClass)

@(private = "file")
patched_application_window_new: proc "c" (_: ^gtk.Application) -> ^gtk.Widget = application_window_new

// Single-object parameters: the C header passes one `T *`, so the parameter is `^T`, not the
// `[^]T` runic writes for a name ending in "s" (scripts/single-object-params.*.txt). One pin per
// type; a regeneration that brings `[^]T` back fails to compile here.

@(private = "file")
patched_carousel_set_scroll_params_single_object: proc "c" (_: ^Carousel, _: ^SpringParams) = carousel_set_scroll_params

@(private = "file")
patched_dialog_set_focus_single_object: proc "c" (_: ^Dialog, _: ^gtk.Widget) = dialog_set_focus

@(private = "file")
patched_entry_row_set_attributes_single_object: proc "c" (_: ^EntryRow, _: ^pango.AttrList) = entry_row_set_attributes

@(private = "file")
patched_length_unit_from_px_single_object: proc "c" (_: LengthUnit, _: f64, _: ^gtk.Settings) -> f64 = length_unit_from_px

@(private = "file")
patched_swipeable_get_snap_points_single_object: proc "c" (_: ^Swipeable, _: ^i32) -> ^f64 = swipeable_get_snap_points
