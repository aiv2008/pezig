const std = @import("std");

// 定义错误集合
pub const ListError = error{
    InvalidState,    // 链表状态无效
    EmptyList,       // 链表为空
    OutOfMemory,     // 内存分配失败
};

const Node = struct {
    data: i32,
    next: ?*Node,
    pre: ?*Node,
    fn new(allocator: std.mem.Allocator, data: i32) !*Node{
        const node_ptr = try allocator.create(Node);
        node_ptr.* = Node{
            .data = data,
            .next = null,
            .pre = null,
        };
        return node_ptr;
    }
};

pub const List: type = struct {
    allocator: std.mem.Allocator,  // 存储 allocator 引用，用于释放内存
    head_ptr: ?*Node,  // 使用可选指针，允许为 null
    tail_ptr: ?*Node,  // 使用可选指针，允许为 null
    capability: i32,
    size: i32,
    
    iter: struct {
        current_ptr: ?*Node,
        list_ptr: ?*List,
        pub fn next(self: *@This()) ?*Node{
            if(self.current_ptr) |ptr| {
                // 先保存当前节点
                // const current = ptr;
                // 移动到下一个节点
                self.current_ptr = ptr.next;
                // 返回当前节点（在移动之前）
                return ptr;
            }
            return null;
        }

        pub fn reset(self: *@This()) void{
            if (self.list_ptr) |list| {
                self.current_ptr = list.head_ptr;
            }
        }
    },
    
    pub fn init(allocator: std.mem.Allocator) !List {
        return List.new(allocator, 8);
    }

    pub fn new(allocator: std.mem.Allocator, capability: i32) !List{
        var list =  List{
            .allocator= allocator,
            .head_ptr = null,
            .tail_ptr = null,
            .capability = capability,
            .size = 0,
            .iter = undefined,
        };
        list.iter = .{
            .list_ptr = &list,
            .current_ptr = null,
        };
        return list;
    }
    
    // 释放 List 及其所有 Node 的内存
    pub fn deinit(self: *List) void {
        // 释放所有 Node
        var current = self.head_ptr;
        while (current) |node| {
            const next = node.next;
            self.allocator.destroy(node);
            current = next;
        }
        // 注意：List 本身的内存由调用者释放（因为 List 是通过指针返回的）
        // 调用者需要：allocator.destroy(list_ptr)
    }

    pub fn add(self: *List, data: i32) !void{
        if(self.size + 1 > self.capability){//扩容
            self.capability <<= 3;
        }
        const node = try Node.new(self.allocator, data);
        
        if(self.head_ptr == null){
            // 空链表：第一个节点既是 head 也是 tail
            self.head_ptr = node;
            self.tail_ptr = node;
        }else{
            // 非空链表：在尾部添加节点
            const old_tail = self.tail_ptr orelse return ListError.InvalidState;
            
            // 建立双向链接
            old_tail.next = node;      // 旧尾节点的 next 指向新节点
            node.pre = old_tail;       // 新节点的 pre 指向旧尾节点
            node.next = null;          // 新节点是新的尾节点，next 为 null
            
            // 更新 tail_ptr
            self.tail_ptr = node;
        }
        self.size += 1;
    }

    pub fn print_list(self: *List) void{
        var current = self.head_ptr;
        // if(current) |ptr|{
        //     std.debug.print("1111 {d} ", .{ptr.data});
        // }else{
        //     std.debug.print("2222", .{});
        // }
        while (current) |ptr| {
            std.debug.print("{d} ", .{ptr.data});
            current = ptr.next;
        }
        // var current_ptr = self.tail_ptr;
        // while (current_ptr) |ptr| {
        //     std.debug.print("{d} ", .{ptr.data});
        //     current_ptr = ptr.pre;
        // }
        std.debug.print("\n", .{});
    }

    pub fn del_head(self: *List) void{
        if (self.head_ptr) |ptr| {
            const node_ptr = ptr;
            const next_node = node_ptr.next;
            
            // 更新 head_ptr
            self.head_ptr = next_node;
            
            // 如果删除的是最后一个节点，需要同时更新 tail_ptr
            if (next_node == null) {
                self.tail_ptr = null;
            } else {
                // 断开新头节点的 pre 指针
                if (next_node) |next| {
                    next.pre = null;
                }
            }
            
            // 销毁节点
            self.allocator.destroy(node_ptr);
            self.size -= 1;
        }
    }

    pub fn del_tail(self: *List) void{
        if (self.tail_ptr) |ptr| {
            const node_ptr = ptr;
            const prev_node = node_ptr.pre;
            
            // 更新 tail_ptr
            self.tail_ptr = prev_node;
            
            // 如果删除的是最后一个节点，需要同时更新 head_ptr
            if (prev_node == null) {
                self.head_ptr = null;
            } else {
                // 断开新尾节点的 next 指针
                if (prev_node) |prev| {
                    prev.next = null;
                }
            }
            
            // 销毁节点
            self.allocator.destroy(node_ptr);
            self.size -= 1;
        }
    }

    pub fn top(self: *List) ListError!i32{
        if (self.tail_ptr) |ptr| {
            return ptr.data;
        }
        return ListError.EmptyList;
    }

    pub fn bottom(self: *List) ListError!i32{
        if (self.head_ptr) |ptr| {
            return ptr.data;
        }
        return ListError.EmptyList;
    }

    pub fn iterator(self: *List) *@TypeOf(self.iter) {
        self.iter.current_ptr = self.head_ptr;
        self.iter.list_ptr = self;
        return &self.iter;
    }
};