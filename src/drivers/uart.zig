const std = @import("std");

/// UART driver for Linux-based embedded systems
const Uart = @This();

device_path: []const u8,
fd: ?std.os.fd_t,

const Error = error{
    DeviceOpenFailed,
    ReadFailed,
    WriteFailed,
};

/// Initialize UART device
pub fn init(allocator: std.mem.Allocator, device_path: []const u8) !Uart {
    const path = try allocator.dupe(u8, device_path);

    const fd = std.os.open(path, std.os.O_RDWR | std.os.O_NOCTTY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.DeviceOpenFailed,
        error.AccessDenied => return Error.DeviceOpenFailed,
        else => return err,
    };

    return Uart{
        .device_path = path,
        .fd = fd,
    };
}

/// Deinitialize UART device
pub fn deinit(self: *Uart, allocator: std.mem.Allocator) void {
    if (self.fd) |fd| {
        std.os.close(fd);
        self.fd = null;
    }
    allocator.free(self.device_path);
}

/// Write data to UART
pub fn write(self: *Uart, data: []const u8) !usize {
    if (self.fd == null) return Error.WriteFailed;

    return std.os.write(self.fd.?, data) catch |err| switch (err) {
        error.DiskQuota => return Error.WriteFailed,
        error.NoSpaceLeft => return Error.WriteFailed,
        error.AccessDenied => return Error.WriteFailed,
        error.IsDir => return Error.WriteFailed,
        error.NameTooLong => return Error.WriteFailed,
        error.ReadOnlyFileSystem => return Error.WriteFailed,
        error.FileTooBig => return Error.WriteFailed,
        error.Unexpected => return Error.WriteFailed,
        else => return err,
    };
}

/// Read data from UART
pub fn read(self: *Uart, buffer: []u8) !usize {
    if (self.fd == null) return Error.ReadFailed;

    return std.os.read(self.fd.?, buffer) catch |err| switch (err) {
        error.IsDir => return Error.ReadFailed,
        error.NotOpenForReading => return Error.ReadFailed,
        error.WouldBlock => return Error.ReadFailed,
        error.Unexpected => return Error.ReadFailed,
        else => return err,
    };
}

/// Read a line from UART (until newline character)
pub fn readLine(self: *Uart, buffer: []u8) !usize {
    if (self.fd == null) return Error.ReadFailed;

    var i: usize = 0;
    while (i < buffer.len - 1) {
        const bytes_read = try std.os.read(self.fd.?, buffer[i .. i + 1]);
        if (bytes_read == 0) break;

        if (buffer[i] == '\n') {
            i += 1;
            break;
        }
        i += bytes_read;
    }
    return i;
}

// Test function for UART driver
test "UART driver functionality" {
    // Note: This test would require actual UART device to run
    // For simulation purposes, we're just checking compilation
    const uart = Uart{
        .device_path = "/dev/null", // Using /dev/null for testing
        .fd = null,
    };
    _ = uart;
}
