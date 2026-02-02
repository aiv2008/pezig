const std = @import("std");
const PEZParser = @import("parser.zig").PEZParser;
const RuntimeParser = @import("parser.zig").RuntimeParser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    std.debug.print("测试 31111: 解析序列操作符\n", .{});
    {
        const grammar =
            \\ab = { \"a\" ~ \"b\" ~ \"c\" }
            \\a = {"oh, "}
            \\b = {"hello"}
            \\c = {"world"}
        ;
        var parser = PEZParser.init(allocator, grammar);
        try parser.parse();
        defer parser.deinit();

        if (parser.rules.get("ab")) |_| {
            std.debug.print("  规则 'ab' 解析成功\n", .{});
            std.debug.print("  规则类型: sequence\n\n", .{});
        }

        var runtimeParser = RuntimeParser.init(allocator, parser.rules);
        const matchResult = try runtimeParser.match("ab", parser.input);
        std.debug.print("success: {}", .{matchResult.success});
    }
}
