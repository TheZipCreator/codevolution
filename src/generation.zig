//! Controls the actual genetic algorithm logic

const std = @import("std");
const Allocator = std.mem.Allocator;
const Random = std.rand.Random;
const Thread = std.Thread;
const assert = std.debug.assert;
const StringHashMap = std.StringHashMap;

const program = @import("program.zig");
const Program = program.Program;
const Instruction = program.Instruction;
const writeCode = program.writeCode;

const Goal = @import("goal.zig").Goal;
const color = @import("color.zig").color;

const TaskManager = @import("task.zig").TaskManager;

/// This structure contains all programs.
pub const Tree = struct {
	const maxChildren: usize = 32; // this is kind of wasteful of memory

	code: []Instruction,
	name: []const u8,
	fitness: i64,
	generation: u64,
	parent: ?*Tree,
	children: []Tree,
	childrenEnd: usize = 0,

	pub fn init(ally: Allocator, p: PrgmFit, generation: u64, parent: ?*Tree) !Tree {
		return Tree {
			.code = p.prgm.code,
			.name = p.prgm.name,
			.fitness = p.fitness,
			.generation = generation,
			.parent = parent,
			.children = try ally.alloc(Tree, maxChildren)
		};
	}

	pub fn addChild(self: *Tree, ally: Allocator, generation: u64, prgm: PrgmFit) !*Tree {
		if(self.childrenEnd >= maxChildren)
			return error.TooManyChildren;
		self.children[self.childrenEnd] = try Tree.init(ally, prgm, generation, self);
		self.childrenEnd += 1;
		return &self.children[self.childrenEnd-1];
	}

	pub fn deinit(self: Tree, ally: Allocator, partial: bool) void {
		if(!partial) {
			ally.free(self.code);
			ally.free(self.name);
		}
		for(self.children[0..self.childrenEnd]) |c|
			c.deinit(ally, partial);
		ally.free(self.children);
	}

	pub fn write(self: Tree, writer: anytype) !void {
		try writer.print(color.green++"Name "++color.default++"- "++color.yellow++"{s}\n", .{self.name});
		try writer.print(color.green++"Generation "++color.default++"- "++color.yellow++"{d}\n", .{self.generation});
		try writer.print(color.green++"Lineage "++color.default++"- ", .{});
		{
			var curr: ?*const Tree = &self;
			var i: usize = 0;
			while(curr) |t| {
				if(i != 0)
					try writer.print(color.default++" <- ", .{});
				try writer.print(color.yellow++"{s}", .{t.name});
				i += 1;
				curr = t.parent;
			}
		}
		try writer.print("\n", .{});
		if(self.childrenEnd > 0) {
			try writer.print(color.green++"Children "++color.default++"- ", .{});
			for(self.children[0..self.childrenEnd], 0..) |c, i| {
				if(i != 0)
					try writer.print(color.default++", ", .{});
				try writer.print(color.yellow++"{s}", .{c.name});
			}
		}
		try writer.print("\n", .{});
		if(self.parent != null) {
			try writer.print(color.green++"Siblings "++color.default++"- ", .{});
			var i: usize = 0;
			for(self.parent.?.children[0..self.parent.?.childrenEnd]) |c| {
				if(std.mem.eql(u8, c.name, self.name))
					continue;
				if(i != 0)
					try writer.print(color.default++", ", .{});
				try writer.print(color.yellow++"{s}", .{c.name});
				i += 1;
			}
			try writer.print("\n", .{});
		}
		try writer.print(color.green++"Fitness "++color.default++"- "++color.yellow++"{d}\n", .{self.fitness});
		try writer.print(color.green++"Code "++color.default++"-\n", .{});
		try writeCode(writer, self.code);
	}

	pub fn graphviz(self: Tree, writer: anytype, prune: bool) !void {
		if(prune and self.childrenEnd == 0)
			return;
		try writer.print("{s};", .{self.name});
		for(self.children[0..self.childrenEnd]) |c| {
			try writer.print("{s}->{s};", .{self.name, c.name});
			try c.graphviz(writer, prune);
		}
	}
};

/// Combination of a program and its fitness
pub const PrgmFit = struct {
	prgm: Program,
	fitness: i64,
	tree: *Tree
};


pub const StatSet = struct {
	mean: f64,
	q1: f64,
	median: f64,
	q3: f64,
	stdDev: f64,

	pub fn write(self: @This(), writer: anytype, name: []const u8) !void {
		try writer.print(color.cyan++"{s}\n", .{name});
		try writer.print(color.green++"  Mean "++color.white++"-"++color.yellow++" {d:.4}\n", .{self.mean});
		try writer.print(color.green++"  Q1 "++color.white++"-"++color.yellow++" {d:.4}\n", .{self.q1});
		try writer.print(color.green++"  Median "++color.white++"-"++color.yellow++" {d:.4}\n", .{self.median});
		try writer.print(color.green++"  Q3 "++color.white++"-"++color.yellow++" {d:.4}\n", .{self.q3});
		try writer.print(color.green++"  Standard Deviation "++color.white++"-"++color.yellow++" {d:.4}\n", .{self.stdDev});
	}
	
	/// Creates a `StatSet` from a dataset. Assumes `dataset` is sorted by `valueOf`.
	pub fn from(comptime T: type, dataset: anytype, valueOf: *const fn(T) f64) !StatSet {
		const info = @typeInfo(@TypeOf(dataset));
		comptime assert(info == .Pointer and info.Pointer.size == .Slice and info.Pointer.child == T);
		const median = valueOf(dataset[@divFloor(dataset.len, 2)]);
		const q1 = valueOf(dataset[@divFloor(dataset.len, 4)]);
		const q3 = valueOf(dataset[@divFloor(dataset.len, 2)+@divFloor(dataset.len, 4)]);
		var mean: f64 = 0;
		var stdDev: f64 = 0;
		for(dataset) |d| {
			mean += valueOf(d);
		}
		mean /= @floatFromInt(dataset.len);
		for(dataset) |d| {
			stdDev += std.math.pow(f64, valueOf(d)-mean, 2);
		}
		stdDev = std.math.sqrt(stdDev);
		return StatSet {
			.mean = mean,
			.q1 = q1,
			.median = median,
			.q3 = q3,
			.stdDev = stdDev
		};
	}
};

/// Stats about a generation
pub const Stats = struct {
	fitness: StatSet,

	pub fn write(self: Stats, writer: anytype) !void {
		try self.fitness.write(writer, "Fitness");
	}
};

/// This struct manages populations.
pub const Generation = struct {
	ally: Allocator,
	programs: []PrgmFit,
	goal: Goal,
	rng: Random,
	count: u64,
	roots: []Tree,
	nameToTree: StringHashMap(*Tree),
	optmem: bool,
	taskManager: TaskManager,
	
	/// Generates a random generation with `size` programs
	pub fn random(ally: Allocator, rng: Random, goal: Goal, size: usize, optmem: bool) !Generation {
		var programs: []PrgmFit = undefined;
		var roots: []Tree = undefined;
		var nameToTree: StringHashMap(*Tree) = undefined;
		if(optmem) {
			programs = blk: {
				const prgms = try ally.alloc(PrgmFit, size);
				for(prgms) |*p|
					p.* = PrgmFit { .prgm = try Program.random(ally, rng), .fitness = 0, .tree = undefined };
				break :blk prgms;
			};
		} else {
			roots = try ally.alloc(Tree, size);
			nameToTree = StringHashMap(*Tree).init(ally);
			programs = blk: {
				const prgms = try ally.alloc(PrgmFit, size);
				for(prgms, 0..) |*p, i| {
					p.* = PrgmFit { .prgm = try Program.random(ally, rng), .fitness = 0, .tree = undefined };
					roots[i] = try Tree.init(ally, p.*, 0, null);
					p.tree = &roots[i];
					try nameToTree.put(p.tree.name, p.tree);
				}
				break :blk prgms;
			};
		}

		return Generation {
			.ally = ally,
			.programs = programs,
			.goal = goal,
			.rng = rng,
			.count = 0,
			.roots = roots,
			.nameToTree = nameToTree,
			.optmem = optmem,
			.taskManager = TaskManager.init()
		};
	}

	pub fn startThreads(self: *Generation) !void {
		try self.taskManager.startThreads();
	}

	/// Frees memory
	pub fn deinit(self: *Generation) void {
		self.taskManager.deinit();
		for(self.programs) |p|
			p.prgm.deinit(self.ally, !self.optmem);
		self.ally.free(self.programs);
		if(!self.optmem) {
			self.nameToTree.deinit();
			for(self.roots) |t|
				t.deinit(self.ally, false);
			self.ally.free(self.roots);
		}
	}

	fn compare(_: void, a: PrgmFit, b: PrgmFit) bool {
		return a.fitness > b.fitness;
	}
	
	pub const programsPerThread = 500;
	pub const numCycles = 1000; // not technically used in here but it's probably best to put it next to the other constant
	
	const RunData = struct {
		ally: Allocator,
		seed: u64,
		goal: Goal,
		cycles: usize,
		optmem: bool,
		prgm: *PrgmFit
	};

	// a single thread running programs
	fn runThread(data_: *anyopaque) !void {
		var data: *RunData = @ptrCast(@alignCast(data_));
		var prng = std.rand.DefaultPrng.init(data.seed);
		const rng = prng.random();
		var p = data.prgm;
		var prgm = &data.prgm.prgm;
		if(data.goal.input == null) {
			prgm.reset();
			for(0..data.cycles) |_| {
				try prgm.cycle();
				if(prgm.terminated())
					break;
			}
			p.fitness = data.goal.fitness(prgm.*);
			if(!data.optmem)
				p.tree.fitness = p.fitness;
		} else {
			prgm.reset();
			const input = try data.goal.input.?(data.ally, rng);
			defer data.ally.free(input);
			prgm.input = input;
			for(0..data.cycles) |_| {
				try prgm.cycle();
				if(prgm.terminated())
					break;
			}
			p.fitness = data.goal.fitness(prgm.*);
			if(!data.optmem)
				p.tree.fitness = p.fitness;
		}
	}

	/// Evaluates fitness for each program. Programs are ran for `cycles` cycles.
	pub fn run(self: *Generation, cycles: u32) !void {
		// create data and tasks
		var data = try self.ally.alloc(RunData, self.programs.len);
		var tasks = try self.ally.alloc(TaskManager.Task, self.programs.len);
		defer self.ally.free(data);
		defer self.ally.free(tasks);
		for(0..self.programs.len) |i| {
			data[i] = .{
				.ally = self.ally,
				.seed = self.rng.int(u64),
				.goal = self.goal,
				.cycles = cycles,
				.optmem = self.optmem,
				.prgm = &self.programs[i]
			};
			tasks[i] = .{
				.data = &data[i],
				.do = &runThread
			};
			self.taskManager.queue(&tasks[i]);
		}
		// wait for threads to finish
		try self.taskManager.wait();
		// sort
		std.sort.heap(PrgmFit, self.programs, {}, compare);
	}

	const ReproduceData = struct {
		src: *PrgmFit,
		dest: *PrgmFit,
		seed: u64,
		mutChance: f64,
		generation: u64,
		optmem: bool,
		ally: Allocator
	};

	pub fn reproduceThread(data_: *anyopaque) !void {
		var data: *ReproduceData = @ptrCast(@alignCast(data_));
		var prng = std.rand.DefaultPrng.init(data.seed);
		const rng = prng.random();
		// kill dest
		data.dest.prgm.deinit(data.ally, !data.optmem);
		// reproduce and mutate
		var clone = try data.src.prgm.clone(data.ally, rng);
		if(rng.float(f64) <= data.mutChance)
			try clone.mutate(data.ally, rng);
		var prgm = PrgmFit { .prgm = clone, .fitness = 0, .tree = undefined };
		if(!data.optmem)
			prgm.tree = try data.src.tree.addChild(data.ally, data.generation, prgm);
		data.dest.* = prgm;
	}

	/// Kills lowest-performing programs, and replicates. `mutChance` represents the chance to mutate, and is a value between 0 and 1
	pub fn reproduce(self: *Generation, mutChance: f64) !void {
		self.count += 1;
		// create tasks
		var data = try self.ally.alloc(ReproduceData, self.programs.len);
		var tasks = try self.ally.alloc(TaskManager.Task, self.programs.len);
		defer self.ally.free(data);
		defer self.ally.free(tasks);
		for(0..self.programs.len/2) |i| {
			data[i] = .{
				.src = &self.programs[i],
				.dest = &self.programs[i+self.programs.len/2],
				.seed = self.rng.int(u64),
				.mutChance = mutChance,
				.generation = self.count,
				.optmem = self.optmem,
				.ally = self.ally
			};
			tasks[i] = .{
				.data = &data[i],
				.do = &reproduceThread
			};
			self.taskManager.queue(&tasks[i]);
		}
		// wait for threads to finish
		try self.taskManager.wait();
		// start threads
		// put new programs' trees in hashmap
		if(!self.optmem)
			for(self.programs[self.programs.len/2..]) |*p|
				try self.nameToTree.put(p.prgm.name, p.tree);
	}

	/// Finds a tree named `name` in this generation, or `null` if not found.
	pub fn findTree(self: Generation, name: []const u8) ?*Tree {
		if(self.optmem)
			return null;
		return self.nameToTree.get(name);
	}
	
	/// Finds a program named `name` in this generation, or `null` if not found.
	pub fn find(self: Generation, name: []const u8) ?PrgmFit {
		var ret: ?PrgmFit = null;
		for(self.programs) |p| {
			if(std.mem.eql(u8, name, p.prgm.name)) {
				ret = p;
				break;
			}
		}
		return ret;
	}

	fn fitnessStat(p: PrgmFit) f64 {
		return @floatFromInt(p.fitness);
	}
	
	/// Creates a Stats struct for this generation
	pub fn stats(self: Generation) Stats {
		return Stats {
			.fitness = try StatSet.from(PrgmFit, self.programs, &fitnessStat)
		};
	}
	
};
