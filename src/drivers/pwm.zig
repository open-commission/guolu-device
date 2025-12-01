const std = @import("std");

/// 使用sysfs接口的Linux嵌入式系统PWM驱动
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

/// 初始化PWM通道
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

/// 反初始化PWM通道
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

/// 通过sysfs导出PWM通道
fn exportChannel(self: *Pwm) !void {
    // 打开导出文件
    var export_path_buf: [64]u8 = undefined;
    const export_path = try std.fmt.bufPrint(&export_path_buf, "/sys/class/pwm/pwmchip{}/export", .{self.chip});
    
    const export_fd = std.os.open(export_path, std.os.O_WRONLY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    defer std.os.close(export_fd);
    
    // 将通道号写入导出文件
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
    
    // 给系统一些时间来创建文件
    std.time.sleep(1000000); // 1ms
    
    // 打开duty_cycle文件进行读写
    var duty_cycle_path_buf: [80]u8 = undefined;
    const duty_cycle_path = try std.fmt.bufPrint(&duty_cycle_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/duty_cycle", .{self.chip, self.channel});
    
    self.fd_duty_cycle = std.os.open(duty_cycle_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    
    // 打开period文件进行读写
    var period_path_buf: [80]u8 = undefined;
    const period_path = try std.fmt.bufPrint(&period_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/period", .{self.chip, self.channel});
    
    self.fd_period = std.os.open(period_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    
    // 打开enable文件进行读写
    var enable_path_buf: [80]u8 = undefined;
    const enable_path = try std.fmt.bufPrint(&enable_path_buf, "/sys/class/pwm/pwmchip{}/pwm{}/enable", .{self.chip, self.channel});
    
    self.fd_enable = std.os.open(enable_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
}

/// 通过sysfs取消导出PWM通道
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

/// 设置PWM周期（纳秒）
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

/// 设置PWM占空比（纳秒）
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

/// 启用/禁用PWM输出
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
    // 注意：此测试需要root权限和实际的PWM硬件才能运行
    // 出于模拟目的，我们只检查编译
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