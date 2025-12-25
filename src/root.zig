//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn bufferedPrint() !void {
    try hello("hello\n");
    var a: u16 = 123;
    const b= &a;
    std.debug.print("a={}, b={}\n", .{a, b});
    // 注意：浮点数精度问题，0.1 + 0.2 != 0.3（二进制浮点数表示的限制）
    // std.debug.assert(0.1 + 0.2 == 0.3); // 这会失败
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn hello(a: []const u8) !void {
    std.debug.print("{s}", .{a});
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

// std.Thread.Mutex 使用示例
const Counter = struct {
    mutex: std.Thread.Mutex = .{},
    value: u32 = 0,

    // 线程安全地增加计数
    fn increment(self: *Counter) void {
        self.mutex.lock();
        defer self.mutex.unlock(); // defer 确保在函数返回时自动解锁
        
        self.value += 1;
    }

    // 线程安全地获取当前值
    fn get(self: *Counter) u32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        return self.value;
    }
};

// 示例：多线程递增计数器
pub fn mutexExample() !void {
    var counter = Counter{};
    var threads: [5]std.Thread = undefined;

    // 创建 5 个线程，每个线程递增计数器 100 次
    for (&threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, struct {
            fn worker(counter_ptr: *Counter, thread_id: usize) void {
                var j: u32 = 0;
                while (j < 100) : (j += 1) {
                    counter_ptr.increment();
                    // 模拟一些工作
                    std.Thread.yield() catch {};
                }
                std.debug.print("线程 {d} 完成\n", .{thread_id});
            }
        }.worker, .{ &counter, i });
    }

    // 等待所有线程完成
    for (&threads) |*thread| {
        thread.join();
    }

    // 最终值应该是 5 * 100 = 500
    std.debug.print("最终计数: {d} (期望: 500)\n", .{counter.get()});
}

// 测试 Mutex 的功能
test "mutex thread safety" {
    var counter = Counter{};
    var threads: [10]std.Thread = undefined;

    // 创建 10 个线程，每个线程递增 10 次
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, struct {
            fn worker(counter_ptr: *Counter) void {
                var i: u32 = 0;
                while (i < 10) : (i += 1) {
                    counter_ptr.increment();
                }
            }
        }.worker, .{&counter});
    }

    // 等待所有线程完成
    for (&threads) |*thread| {
        thread.join();
    }

    // 验证最终值是否正确（10 个线程 × 10 次 = 100）
    try std.testing.expectEqual(@as(u32, 100), counter.get());
}

// ============================================================================
// Zig 鸭子类型（Duck Typing）示例
// ============================================================================
// 鸭子类型：如果它走起来像鸭子，叫起来像鸭子，那它就是鸭子
// 在 Zig 中：如果结构体有需要的字段/方法，就可以使用它，无需显式声明接口

// 示例 1: 通过字段匹配实现多态
// 定义一个函数，接受任何有 'name' 字段的类型
pub fn printName(comptime T: type, obj: T) void {
    std.debug.print("名字: {s}\n", .{obj.name});
}

// 不同的结构体，但都有 'name' 字段
const Dog = struct {
    name: []const u8,
    breed: []const u8,
};

const Cat = struct {
    name: []const u8,
    color: []const u8,
};

const Person = struct {
    name: []const u8,
    age: u32,
};

pub fn duckTypingExample1() void {
    std.debug.print("\n=== 鸭子类型示例 1: 字段匹配 ===\n", .{});
    
    const dog = Dog{ .name = "旺财", .breed = "金毛" };
    const cat = Cat{ .name = "小花", .color = "橘色" };
    const person = Person{ .name = "张三", .age = 30 };
    
    // 这三个不同的类型都可以使用 printName 函数
    printName(Dog, dog);
    printName(Cat, cat);
    printName(Person, person);
}

// 示例 2: 通过方法匹配实现多态
// 定义一个函数，接受任何有 'speak' 方法的类型
pub fn makeItSpeak(comptime T: type, obj: *T) void {
    obj.speak();
}

// 不同的结构体，都有 'speak' 方法
const Bird = struct {
    name: []const u8,
    
    pub fn speak(self: *const Bird) void {
        std.debug.print("{s} 说: 啾啾啾\n", .{self.name});
    }
};

const Duck = struct {
    name: []const u8,
    
    pub fn speak(self: *const Duck) void {
        std.debug.print("{s} 说: 嘎嘎嘎（这就是鸭子类型！）\n", .{self.name});
    }
};

const Robot = struct {
    id: u32,
    
    pub fn speak(self: *const Robot) void {
        std.debug.print("机器人 #{d} 说: 哔哔哔\n", .{self.id});
    }
};

pub fn duckTypingExample2() void {
    std.debug.print("\n=== 鸭子类型示例 2: 方法匹配 ===\n", .{});
    
    var bird = Bird{ .name = "小鸟" };
    var duck = Duck{ .name = "鸭子" };
    var robot = Robot{ .id = 42 };
    
    // 这三个不同的类型都可以使用 makeItSpeak 函数
    makeItSpeak(Bird, &bird);
    makeItSpeak(Duck, &duck);
    makeItSpeak(Robot, &robot);
}

// 示例 3: 更复杂的鸭子类型 - Writer 接口
// 任何有 'write' 方法的类型都可以作为 Writer
pub fn writeSomething(comptime Writer: type, writer: Writer, data: []const u8) !void {
    _ = try writer.write(data);
}

// 不同的 Writer 实现
const ConsoleWriter = struct {
    pub fn write(self: @This(), data: []const u8) !usize {
        _ = self;
        // 使用 std.debug.print 作为示例（实际中可以使用文件或其他输出）
        std.debug.print("{s}", .{data});
        return data.len;
    }
};

const MemoryWriter = struct {
    buffer: []u8,
    pos: usize = 0,
    
    pub fn write(self: *@This(), data: []const u8) !usize {
        if (self.pos + data.len > self.buffer.len) {
            return error.BufferTooSmall;
        }
        @memcpy(self.buffer[self.pos..][0..data.len], data);
        self.pos += data.len;
        return data.len;
    }
    
    pub fn getWritten(self: *const @This()) []const u8 {
        return self.buffer[0..self.pos];
    }
};

pub fn duckTypingExample3() !void {
    std.debug.print("\n=== 鸭子类型示例 3: Writer 接口 ===\n", .{});
    
    // 使用 ConsoleWriter
    const console = ConsoleWriter{};
    try writeSomething(ConsoleWriter, console, "Hello from ConsoleWriter!\n");
    
    // 使用 MemoryWriter
    var buffer: [100]u8 = undefined;
    var memory = MemoryWriter{ .buffer = &buffer };
    try writeSomething(*MemoryWriter, &memory, "Hello from MemoryWriter!\n");
    
    std.debug.print("MemoryWriter 写入的内容: {s}", .{memory.getWritten()});
}

// 示例 4: 使用 comptime 实现更灵活的鸭子类型检查
pub fn processWithMethod(comptime T: type, _: T, method_name: []const u8) void {
    // 检查类型是否有指定的方法（这里简化展示概念）
    std.debug.print("处理对象，调用方法: {s}\n", .{method_name});
    // 在实际代码中，可以使用 @hasDecl 检查方法是否存在
    // comptime {
    //     if (!@hasDecl(T, method_name)) {
    //         @compileError("类型缺少方法: " ++ method_name);
    //     }
    // }
}

// 示例 5: 标准库中的鸭子类型示例
// std.io.Writer 就是一个鸭子类型接口
// 任何有 write/writeAll 等方法的类型都可以作为 Writer 使用
pub fn stdLibraryDuckTyping() !void {
    std.debug.print("\n=== 鸭子类型示例 4: 标准库 Writer ===\n", .{});
    
    std.debug.print("使用标准库 Writer 接口\n", .{});
    
    // ArrayList(u8).Writer 是一个 Writer 实现
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var list = std.ArrayList(u8){};
    defer list.deinit(gpa.allocator());
    
    const list_writer = list.writer(gpa.allocator());
    try list_writer.print("写入到 ArrayList\n", .{});
    
    std.debug.print("从 ArrayList 读取: {s}", .{list.items});
}

// 综合示例
pub fn duckTypingExample() !void {
    std.debug.print("\n=== Zig 鸭子类型（Duck Typing）完整示例 ===\n", .{});
    std.debug.print("概念: 如果类型有需要的字段/方法，就可以使用，无需显式接口声明\n\n", .{});
    
    duckTypingExample1();
    duckTypingExample2();
    try duckTypingExample3();
    try stdLibraryDuckTyping();
}

// 测试鸭子类型
test "duck typing with name field" {
    const dog = Dog{ .name = "TestDog", .breed = "TestBreed" };
    printName(Dog, dog);
}

test "duck typing with speak method" {
    var bird = Bird{ .name = "TestBird" };
    makeItSpeak(Bird, &bird);
}
