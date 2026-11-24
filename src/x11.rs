//! Keep-above requests for X11 and XWayland window managers.

use std::ffi::{c_int, c_long, c_ulong, c_void};

use gtk::{gdk, glib::translate::ToGlibPtr};

#[repr(C)]
struct ClientMessage {
    kind: c_int,
    serial: c_ulong,
    send_event: c_int,
    display: *mut c_void,
    window: c_ulong,
    message_type: c_ulong,
    format: c_int,
    data: [c_long; 5],
}

// Xlib defines XEvent as a union with space for 24 longs.
#[repr(C)]
union XEvent {
    client: std::mem::ManuallyDrop<ClientMessage>,
    padding: [c_long; 24],
}

#[link(name = "gtk-4")]
unsafe extern "C" {
    fn gdk_x11_display_get_xdisplay(display: *mut gdk::ffi::GdkDisplay) -> *mut c_void;
    fn gdk_x11_display_get_xrootwindow(display: *mut gdk::ffi::GdkDisplay) -> c_ulong;
    fn gdk_x11_surface_get_xid(surface: *mut gdk::ffi::GdkSurface) -> c_ulong;
}

#[link(name = "X11")]
unsafe extern "C" {
    fn XInternAtom(display: *mut c_void, name: *const std::ffi::c_char, only_if_exists: c_int) -> c_ulong;
    fn XSendEvent(display: *mut c_void, window: c_ulong, propagate: c_int, mask: c_long, event: *mut XEvent) -> c_int;
    fn XFlush(display: *mut c_void) -> c_int;
}

pub fn supports(display: &gdk::Display) -> bool {
    use gtk::prelude::*;
    display.type_().name() == "GdkX11Display"
}

pub fn set_above(surface: &gdk::Surface, above: bool) {
    use gtk::prelude::*;
    let display = surface.display();
    if !supports(&display) || surface.is_destroyed() {
        return;
    }
    // The surface owns a live XID on this X11 display. EWMH asks clients to
    // send _NET_WM_STATE to the root window when changing a mapped window.
    unsafe {
        let xdisplay = gdk_x11_display_get_xdisplay(display.to_glib_none().0);
        let root = gdk_x11_display_get_xrootwindow(display.to_glib_none().0);
        let xid = gdk_x11_surface_get_xid(surface.to_glib_none().0);
        let state = XInternAtom(xdisplay, c"_NET_WM_STATE".as_ptr(), 0);
        let above_atom = XInternAtom(xdisplay, c"_NET_WM_STATE_ABOVE".as_ptr(), 0);
        let mut event = XEvent { padding: [0; 24] };
        event.client = std::mem::ManuallyDrop::new(ClientMessage {
            kind: 33, // ClientMessage
            serial: 0,
            send_event: 0,
            display: xdisplay,
            window: xid,
            message_type: state,
            format: 32,
            data: [c_long::from(above), above_atom as c_long, 0, 1, 0],
        });
        let root_mask = (1 << 19) | (1 << 20); // SubstructureNotifyMask | SubstructureRedirectMask
        XSendEvent(xdisplay, root, 0, root_mask, &mut event);
        XFlush(xdisplay);
    }
}
