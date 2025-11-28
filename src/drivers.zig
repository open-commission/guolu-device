const std = @import("std");

pub const adc = @import("drivers/adc.zig");
pub const uart = @import("drivers/uart.zig");
pub const gpio = @import("drivers/gpio.zig");
pub const pwm = @import("drivers/pwm.zig");

test "driver modules compilation" {
    _ = adc;
    _ = uart;
    _ = gpio;
    _ = pwm;
    
    // Run all driver tests
    _ = @import("drivers/adc.zig");
    _ = @import("drivers/uart.zig");
    _ = @import("drivers/gpio.zig");
    _ = @import("drivers/pwm.zig");
}