//! Callback handling utilities for mobile FFI

use std::ffi::CString;
use std::os::raw::c_char;

/// Helper to convert Rust string to C string for callbacks
pub fn to_c_string(s: &str) -> Option<CString> {
    CString::new(s).ok()
}

/// Helper to safely invoke a callback with error handling
pub unsafe fn invoke_callback_safe<F>(f: F)
where
    F: FnOnce() + std::panic::UnwindSafe,
{
    // Catch panics to prevent unwinding into C code
    let _ = std::panic::catch_unwind(f);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_to_c_string() {
        let s = to_c_string("test");
        assert!(s.is_some());

        let s_with_null = to_c_string("test\0string");
        assert!(s_with_null.is_none()); // Should fail due to interior null
    }
}
