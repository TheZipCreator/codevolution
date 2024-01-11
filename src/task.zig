///! Handles a task queue for multithreading

const std = @import("std");
const Allocator = std.mem.Allocator;
const Thread = std.Thread;
const Atomic = std.atomic.Value;
const ms = std.time.ns_per_ms;

/// The struct that handles task management.
pub const TaskManager = struct {
	const Self = @This();
	
	pub const Task = struct {
		data: *anyopaque,
		do: *const fn(data: *anyopaque) anyerror!void,
		next: ?*Task = null,
	};

	const threadCount = 32;

	top: ?*Task = null,
	lock: Thread.Mutex = .{},
	threads: [threadCount]Thread = undefined,
	done: Atomic(bool) = undefined,
	totalTasks: u64 = 0, // total tasks requested
	tasksCompleted: Atomic(u64), // total tasks completed

	pub fn init() Self {
		return Self {
			.done = Atomic(bool).init(false),
			.tasksCompleted = Atomic(u64).init(0)
		};
	}

	pub fn deinit(self: *Self) void {
		self.done.store(true, .Monotonic);
		for(&self.threads) |*t| {
			t.join();
		}
	}

	pub fn startThreads(self: *Self) !void {
		for(&self.threads) |*t|
			t.* = try Thread.spawn(.{}, doTasks, .{self});
	}

	pub fn queue(self: *Self, task: *Task) void {
		self.totalTasks += 1;
		self.lock.lock();
		defer self.lock.unlock();
		task.next = self.top;
		self.top = task;
	}

	pub fn dequeue(self: *Self) ?*Task {
		self.lock.lock();
		defer self.lock.unlock();
		if(self.top == null)
			return null;
		const top = self.top;
		self.top = self.top.?.next;
		return top;
	}

	const inactivityDelay = 200*ms;

	fn doTasks(self: *Self) !void {
		// after 1 second of inactivity, this continually sleeps for one second.
		var lastActive = std.time.nanoTimestamp();
		while(true) {
			while(self.dequeue()) |task| {
				try task.do(task.data);
				lastActive = std.time.nanoTimestamp();
				_ = self.tasksCompleted.fetchAdd(1, .Monotonic);
			}
			if(std.time.nanoTimestamp()-lastActive < inactivityDelay)
				continue;
			if(self.done.load(.Monotonic))
				break;
			std.time.sleep(inactivityDelay);
		}
	}

	pub fn wait(self: *Self) !void {
		while(self.tasksCompleted.load(.Monotonic) != self.totalTasks) {
			std.time.sleep(1);
		}
	}

};
