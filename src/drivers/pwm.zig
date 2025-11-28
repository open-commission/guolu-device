const std = @import("std");

/// PWM driver for Linux-based embedded systems using sysfs interface
const Pwm = @This();

chip: u32,
channel: u32,
exported: bool,
fd_duty_cycle: ?std.os.fd_t,
fd_period: ?std.os.fd_t,
fd_enable: ?std.os.fd_t,

const Error = error{
    ExportFailed,
    UnexportFailed,
    SetPeriodFailed,
    SetDutyCycleFailed,
    EnableFailed,
};

/// Initialize PWM channel
pub fn init(chip: u32, channel: u32) !Pwm {
    var pwm = Pwm{
        .chip = chip,
        .channel = channel,
        .exported = false,
        .fd_duty_cycle = null,
        .fd_period = null,
        .fd_enable = null,
    };
    
    // Export the PWM channel
    try pwm.exportChannel();
    pwm.exported = true;
    
    return pwm;
}

/// Deinitialize PWM channel
pub fn deinit(self: *Pwm) void {
    if (self.fd_duty_cycle) |fd| {
        std.os.close(fd);
    }
    if (self.fd_period) |fd| {
        std.os.close(fd);
    }
    if (self.fd_enable) |fd| {
        std.os.close(fd);
    }
    if (self.exported) {
        self.unexportChannel() catch {};
    }
}

/// Export PWM channel through sysfs
fn exportChannel(self: *Pwm) !void {
    // Open the export file
    var export_path_buf: [64]u8 = undefined;
    const export_path = try std.fmt.bufPrint(&export_path_buf, "/sys/class/pwm/pwmchip{}/export", .{self.chip});
    
    const export_fd = std.os.open(export_path, std.os.O_WRONLY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    defer std.os.close(export_fd);
    
    // Write channel number to export
    var buffer: [16]u8 = undefined;
    const channel_str = try std.fmt.bufPrint(&buffer, "{}\n", .{self.channel});
    _ = std.os.write(export_fd, channel_str) catch |err| switch (err) {
        error.DiskQuota => return Error.ExportFailed,
        error.NoSpaceLeft => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        error.IsDir => return Error.ExportFailed,
        error.NameTooLong => return Error.ExportFailed,
        error.ReadOnlyFileSystem => return Error.ExportFailed,
        error.FileTooBig => return Error.ExportFailed,
        error.Unexpected => return Error.ExportFailed,
        else => return err,
    };
    
    // Give the system a moment to create the files
    std.time.sleep(1000000); // 1ms
    
    // Open duty_cycle file for read/write
    var duty_cycle_path_buf: [80]u8 = undefined;
    const duty_cycle_path = try std.fmt.bufPrint(&duty_cycle_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/duty_cycle", .{self.chip, self.channel});
    
    self.fd_duty_cycle = std.os.open(duty_cycle_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    
    // Open period file for read/write
    var period_path_buf: [80]u8 = undefined;
    const period_path = try std.fmt.bufPrint(&period_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/period", .{self.chip, self.channel});
    
    self.fd_period = std.os.open(period_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    
    // Open enable file for read/write
    var enable_path_buf: [80]u8 = undefined;
    const enable_path = try std.fmt.bufPrint(&enable_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/enable", .{self.chip, self.channel});
    
    self.fd_enable = std.os.open(enable_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
}

/// Unexport PWM channel through sysfs
fn unexportChannel(self: *Pwm) !void {
    var unexport_path_buf: [64]u8 = undefined;
    const unexport_path = try std.fmt.bufPrint(&unexport_path_buf, "/sys/class/pwm/pwmchip{}/unexport", .{self.chip});
    
    const unexport_fd = std.os.open(unexport_path, std.os.O_WRONLY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.UnexportFailed,
        error.AccessDenied => return Error.UnexportFailed,
        else => return err,
    };
    defer std.os.close(unexport_fd);
    
    var buffer: [16]u8 = undefined;
    const channel_str = try std.fmt.bufPrint(&buffer, "{}\n", .{self.channel});
    _ = std.os.write(unexport_fd, channel_str) catch |err| switch (err) {
        error.DiskQuota => return Error.UnexportFailed,
        error.NoSpaceLeft => return Error.UnexportFailed,
        error.AccessDenied => return Error.UnexportFailed,
        error.IsDir => return Error.UnexportFailed,
        error.NameTooLong => return Error.UnexportFailed,
        error.ReadOnlyFileSystem => return Error.UnexportFailed,
        error.FileTooBig => return Error.UnexportFailed,
        error.Unexpected => return Error.UnexportFailed,
        else => return err,
    };
}

/// Set PWM period in nanoseconds
pub fn setPeriod(self: *Pwm, period_ns: u32) !void {
    if (self.fd_period == null) return Error.SetPeriodFailed;
    
    var buffer: [32]u8 = undefined;
    const period_str = try std.fmt.bufPrint(&buffer, "{}\n", .{period_ns});
    
    _ = std.os.write(self.fd_period.?, period_str) catch |err| switch (err) {
        error.DiskQuota => return Error.SetPeriodFailed,
        error.NoSpaceLeft => return Error.SetPeriodFailed,
        error.AccessDenied => return Error.SetPeriodFailed,
        error.IsDir => return Error.SetPeriodFailed,
        error.NameTooLong => return Error.SetPeriodFailed,
        error.ReadOnlyFileSystem => return Error.SetPeriodFailed,
        error.FileTooBig => return Error.SetPeriodFailed,
        error.Unexpected => return Error.SetPeriodFailed,
        else => return err,
    };
}

/// Set PWM duty cycle in nanoseconds
pub fn setDutyCycle(self: *Pwm, duty_cycle_ns: u32) !void {
    if (self.fd_duty_cycle == null) return Error.SetDutyCycleFailed;
    
    var buffer: [32]u8 = undefined;
    const duty_cycle_str = try std.fmt.bufPrint(&buffer, "{}\n", .{duty_cycle_ns});
    
    _ = std.os.write(self.fd_duty_cycle.?, duty_cycle_str) catch |err| switch (err) {
        error.DiskQuota => return Error.SetDutyCycleFailed,
        error.NoSpaceLeft => return Error.SetDutyCycleFailed,
        error.AccessDenied => return Error.SetDutyCycleFailed,
        error.IsDir => return Error.SetDutyCycleFailed,
        error.NameTooLong => return Error.SetDutyCycleFailed,
        error.ReadOnlyFileSystem => return Error.SetDutyCycleFailed,
        error.FileTooBig => return Error.SetDutyCycleFailed,
        error.Unexpected => return Error.SetDutyCycleFailed,
        else => return err,
    };
}

/// Enable/disable PWM output
pub fn enable(self: *Pwm, enabled: bool) !void {
    if (self.fd_enable == null) return Error.EnableFailed;
    
    const enable_str = if (enabled) "1\n" else "0\n";
    
    _ = std.os.write(self.fd_enable.?, enable_str) catch |err| switch (err) {
        error.DiskQuota => return Error.EnableFailed,
        error.NoSpaceLeft => return Error.EnableFailed,
        error.AccessDenied => return Error.EnableFailed,
        error.IsDir => return Error.EnableFailed,
        error.NameTooLong => return Error.EnableFailed,
        error.ReadOnlyFileSystem => return Error.EnableFailed,
        error.FileTooBig => return Error.EnableFailed,
        error.Unexpected => return Error.EnableFailed,
        else => return err,
    };
}

// Test function for PWM driver
test "PWM driver functionality" {
    // Note: This test would require root access and actual PWM hardware to run
    // For simulation purposes, we're just checking compilation
    const pwm = Pwm{
        .chip = 0,
        .channel = 0,
        .exported = false,
        .fd_duty_cycle = null,
        .fd_period = null,
        .fd_enable = null,
    };
    _ = pwm;
}