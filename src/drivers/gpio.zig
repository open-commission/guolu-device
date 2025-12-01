const std = @import("std");

/// 使用sysfs接口的Linux嵌入式系统的GPIO驱动程序
const Gpio = @This();

pin_number: u32,
exported: bool,
fd_value: ?std.os.fd_t,
fd_direction: ?std.os.fd_t,

const Direction = enum {
    in,
    out,
};

const Error = error{
    ExportFailed,
    UnexportFailed,
    SetDirectionFailed,
    SetValueFailed,
    GetValueFailed,
};

/// 初始化GPIO引脚
pub fn init(pin_number: u32) !Gpio {
    var gpio = Gpio{
        .pin_number = pin_number,
        .exported = false,
        .fd_value = null,
        .fd_direction = null,
    };
    
    // 导出GPIO引脚
    try gpio.exportPin();
    gpio.exported = true;
    
    return gpio;
}

/// 取消初始化GPIO引脚
pub fn deinit(self: *Gpio) void {
    if (self.fd_value) |fd| {
        std.os.close(fd);
    }
    if (self.fd_direction) |fd| {
        std.os.close(fd);
    }
    if (self.exported) {
        self.unexportPin() catch {};
    }
}

/// 通过sysfs导出GPIO引脚
fn exportPin(self: *Gpio) !void {
    // 打开导出文件
    const export_fd = std.os.open("/sys/class/gpio/export", std.os.O_WRONLY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    defer std.os.close(export_fd);
    
    // 写入引脚号以导出
    var buffer: [16]u8 = undefined;
    const pin_str = try std.fmt.bufPrint(&buffer, "{}\n", .{self.pin_number});
    _ = std.os.write(export_fd, pin_str) catch |err| switch (err) {
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
    
    // 给系统一点时间创建文件
    std.time.sleep(1000000); // 1ms
    
    // 打开值文件进行读写
    var value_path_buf: [64]u8 = undefined;
    const value_path = try std.fmt.bufPrint(&value_path_buf, "/sys/class/gpio/gpio{}/value", .{self.pin_number});
    
    self.fd_value = std.os.open(value_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
    
    // 打开方向文件进行读写
    var direction_path_buf: [64]u8 = undefined;
    const direction_path = try std.fmt.bufPrint(&direction_path_buf, "/sys/class/gpio/gpio{}/direction", .{self.pin_number});
    
    self.fd_direction = std.os.open(direction_path, std.os.O_RDWR, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.ExportFailed,
        error.AccessDenied => return Error.ExportFailed,
        else => return err,
    };
}

/// 通过sysfs取消导出GPIO引脚
fn unexportPin(self: *Gpio) !void {
    const unexport_fd = std.os.open("/sys/class/gpio/unexport", std.os.O_WRONLY, 0) catch |err| switch (err) {
        error.FileNotFound => return Error.UnexportFailed,
        error.AccessDenied => return Error.UnexportFailed,
        else => return err,
    };
    defer std.os.close(unexport_fd);
    
    var buffer: [16]u8 = undefined;
    const pin_str = try std.fmt.bufPrint(&buffer, "{}\n", .{self.pin_number});
    _ = std.os.write(unexport_fd, pin_str) catch |err| switch (err) {
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

/// 设置GPIO引脚方向
pub fn setDirection(self: *Gpio, direction: Direction) !void {
    if (self.fd_direction == null) return Error.SetDirectionFailed;
    
    const direction_str = switch (direction) {
        .in => "in\n",
        .out => "out\n",
    };
    
    _ = std.os.write(self.fd_direction.?, direction_str) catch |err| switch (err) {
        error.DiskQuota => return Error.SetDirectionFailed,
        error.NoSpaceLeft => return Error.SetDirectionFailed,
        error.AccessDenied => return Error.SetDirectionFailed,
        error.IsDir => return Error.SetDirectionFailed,
        error.NameTooLong => return Error.SetDirectionFailed,
        error.ReadOnlyFileSystem => return Error.SetDirectionFailed,
        error.FileTooBig => return Error.SetDirectionFailed,
        error.Unexpected => return Error.SetDirectionFailed,
        else => return err,
    };
}

/// 设置GPIO引脚值（高/低）
pub fn setValue(self: *Gpio, value: bool) !void {
    if (self.fd_value == null) return Error.SetValueFailed;
    
    const value_str = if (value) "1\n" else "0\n";
    
    _ = std.os.write(self.fd_value.?, value_str) catch |err| switch (err) {
        error.DiskQuota => return Error.SetValueFailed,
        error.NoSpaceLeft => return Error.SetValueFailed,
        error.AccessDenied => return Error.SetValueFailed,
        error.IsDir => return Error.SetValueFailed,
        error.NameTooLong => return Error.SetValueFailed,
        error.ReadOnlyFileSystem => return Error.SetValueFailed,
        error.FileTooBig => return Error.SetValueFailed,
        error.Unexpected => return Error.SetValueFailed,
        else => return err,
    };
}

/// 获取GPIO引脚值
pub fn getValue(self: *Gpio) !bool {
    if (self.fd_value == null) return Error.GetValueFailed;
    
    var buffer: [4]u8 = undefined;
    _ = try std.os.lseek(self.fd_value.?, 0, std.os.SEEK_SET);
    const bytes_read = try std.os.read(self.fd_value.?, buffer[0..]);
    
    if (bytes_read > 0) {
        return buffer[0] == '1';
    }
    
    return Error.GetValueFailed;
}

// GPIO驱动程序的测试函数
test "GPIO driver functionality" {
    // Note: This test would require root access and actual GPIO pins to run
    // For simulation purposes, we're just checking compilation
    const gpio = Gpio{
        .pin_number = 18,
        .exported = false,
        .fd_value = null,
        .fd_direction = null,
    };
    _ = gpio;
}