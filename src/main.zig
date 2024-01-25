//! Main module. Implements command logic and ties everything together

const std = @import("std");
const ArrayList = std.ArrayList;
const eql = std.mem.eql;
const nanoTimestamp = std.time.nanoTimestamp;
const ns_per_s = std.time.ns_per_s;

const color = @import("./color.zig").color;
const generation = @import("./generation.zig");
const Generation = generation.Generation;
const Tree = generation.Tree;

const goals = @import("./goal.zig").goals;

const Program = @import("./program.zig").Program;

/// Main function
pub fn main() !void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	defer _ = gpa.deinit();
	const ally = gpa.allocator();

	const stdout = std.io.getStdOut().writer();
	const stdin = std.io.getStdIn().reader();
	
	var seed: u64 = @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())));
	var prng = std.rand.DefaultPrng.init(seed);
	var rng = prng.random();

	var gen: ?Generation = null;
	defer {
		if(gen != null)
			gen.?.deinit();
	}

	var mutChance: f64 = 1;
	var goal = goals.print1;
	var optmem: bool = false;

	while(true) {
		try stdout.print(color.magenta++"(codevolution) "++color.default, .{});
		const str = stdin.readUntilDelimiterAlloc(ally, '\n', std.math.maxInt(usize)) catch |e| {
			if(e == error.EndOfStream)
				break;
			return e;
		};
		defer ally.free(str);
		const split: [][]const u8 = blk: {
			var list = ArrayList([]const u8).init(ally);
			var iter = std.mem.splitScalar(u8, str, ' ');
			while(iter.next()) |n| {
				try list.append(n);
			}
			break :blk try list.toOwnedSlice();
		};
		defer ally.free(split);
		const cmd = split[0];
		if(cmd.len == 0)
			continue;
		const args = split[1..];
		if(eql(u8, cmd, "exit")) {
			_ = try getArgs(stdout, args, .{}) orelse continue;
			break;
		}
		if(eql(u8, cmd, "seed")) {
			const a = try getArgs(stdout, args, .{?u64}) orelse continue;
			if(a[0] == null) {
				try stdout.print("Seed is {d}\n", .{seed});
				continue;
			}
			seed = a[0].?;
			prng = std.rand.DefaultPrng.init(seed);
			rng = prng.random();
			try stdout.print("Set seed to {d}.\n", .{seed});
			continue;
		}
		if(eql(u8, cmd, "new")) {
			const a = try getArgs(stdout, args, .{?usize}) orelse continue;
			if(gen != null)
				gen.?.deinit();
			try stdout.print(color.cyan++"Generation #1\n"++color.default, .{});
			try stdout.print(  "Creating generation...", .{});
			gen = try Generation.random(ally, rng, goal, a[0] orelse 1000, optmem);
			try gen.?.startThreads();
			try stdout.print("\rGeneration created.   \n", .{});
			try stdout.print(  "Running generation...", .{});
			try gen.?.run(Generation.numCycles);
			try stdout.print("\rGeneration ran.      \n", .{});
			continue;
		}
		if(eql(u8, cmd, "next")) {
			const a = try getArgs(stdout, args, .{?u64}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be succeeded.\n", .{});
				continue;
			}
			const startTime = nanoTimestamp();
			for(0..(a[0] orelse 1)) |_| {
				try stdout.print(color.cyan++"Generation #{d}\n"++color.default, .{gen.?.count+2});
				try stdout.print(  "Reproducing...", .{});
				try gen.?.reproduce(mutChance);
				try stdout.print("\rPrograms reproduced.\n", .{});
				try stdout.print(  "Running generation...", .{});
				try gen.?.run(Generation.numCycles);
				try stdout.print("\rGeneration ran.      \n", .{});
			}
			try stdout.print(color.green++"Ran {d} generations in {d:.3} seconds.\n", .{a[0] orelse 1, @as(f64, @floatFromInt(nanoTimestamp()-startTime))/@as(f64, @floatFromInt(ns_per_s))});
			continue;	
		}
		if(eql(u8, cmd, "ls")) {
			const a = try getArgs(stdout, args, .{?usize}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be viewed.\n", .{});
				continue;
			}
			const max = a[0] orelse 25;
			for(gen.?.programs, 0..) |p, i| {
				if(i > max-1)
					break;
				try stdout.print(color.green++"#{d}"++color.white++" - "++color.yellow++"{s}"++color.white++" (fitness: {d})\n", .{i+1, p.prgm.name, p.fitness});
			}
			if(gen.?.programs.len > max)
				try stdout.print("[{d} more entries...]\n", .{gen.?.programs.len-max});
			continue;
		}
		if(eql(u8, cmd, "view")) {
			const a = try getArgs(stdout, args, .{[]const u8}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be viewed.\n", .{});
				continue;
			}
			const name = a[0];
			if(optmem) {
				const prgm = gen.?.find(name) orelse {
					try stdout.print(color.red++"Can not find program named '{s}'.\n", .{name});
					continue;
				};
				var t = try Tree.init(ally, prgm, gen.?.count, null);
				defer t.deinit(ally, true);
				try t.write(stdout);
				continue;
			}
			var prgm = gen.?.findTree(name) orelse {
				try stdout.print(color.red++"Can not find program named '{s}'.\n", .{name});
				continue;
			};
			try prgm.write(stdout);
			continue;
		}
		if(eql(u8, cmd, "out")) {
			const a = try getArgs(stdout, args, .{[]const u8, ?bool}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be viewed.\n", .{});
				continue;
			}
			const name = a[0];
			const prgm = gen.?.find(name) orelse {
				const prgm = gen.?.findTree(name) orelse {
					try stdout.print(color.red++"Can not find program named '{s}'.\n", .{name});
					continue;
				};
				// output isn't recorded, so we have to re-run it to see output.
				var p = try Program.init(ally, prgm.name, prgm.code);
				defer p.deinit(ally, true);
				p.reset();
				for(0..Generation.numCycles) |_| {
					try p.cycle();
					if(p.terminated())
						break;
				}
				const arr = p.output.items;
				if(if(a[1] != null) a[1].? else goal.outputAsString) {
					try stdout.print(color.default++"{s}\n", .{arr});
				} else
					try stdout.print(color.default++"{any}\n", .{arr});
				continue;
			};
			// it's in the current generation, so we can see output
			const arr = prgm.prgm.output.items;
			if(if(a[1] != null) a[1].? else goal.outputAsString) {
				try stdout.print(color.default++"{s}\n", .{arr});
			} else
				try stdout.print(color.default++"{any}\n", .{arr});
			continue;
		}
		if(eql(u8, cmd, "mut")) {
			const a = try getArgs(stdout, args, .{?f64}) orelse continue;
			if(a[0] == null) {
				try stdout.print("Mutation chance is {d:.2}%\n", .{mutChance*100});
				continue;
			}
			mutChance = a[0].?/100.0;
			try stdout.print("Mutation chance set to {d:.2}%\n", .{mutChance*100});
			continue;
		}
		if(eql(u8, cmd, "goal")) {
			const a = try getArgs(stdout, args, .{?[]const u8}) orelse continue;
			if(a[0] == null) {
				try goal.write(stdout);
				continue;
			}
			const name = a[0].?;
			goal = blk: {
				inline for(@typeInfo(@TypeOf(goals)).Struct.fields) |f| {
					const g = @field(goals, f.name);
					if(eql(u8, g.name, name))
						break :blk g;
				}
				try stdout.print(color.red++"Could not find goal named '{s}'. Type `goals` to see a list of goals.\n", .{name});
				continue;
			};
			try stdout.print("Goal set to {s}.\n", .{name});
			continue;
		}
		if(eql(u8, cmd, "goals")) {
			_ = try getArgs(stdout, args, .{}) orelse continue;
			inline for(@typeInfo(@TypeOf(goals)).Struct.fields) |f|
				try @field(goals, f.name).write(stdout);
			continue;
		}
		if(eql(u8, cmd, "clear")) {
			_ = try getArgs(stdout, args, .{}) orelse continue;
			try stdout.print("\x1B[2J\x1B[H", .{});
			continue;
		}
		if(eql(u8, cmd, "stats")) {
			_ = try getArgs(stdout, args, .{}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be viewed.\n", .{});
				continue;
			}
			const stats = gen.?.stats();
			try stats.write(stdout);
			continue;
		}
		if(eql(u8, cmd, "optmem")) {
			const a = try getArgs(stdout, args, .{bool}) orelse continue;
			optmem = a[0];
			try stdout.print("Memory optimization has been {s}"++color.default++".\n", .{if(optmem) color.green++"enabled" else color.red++"disabled"});
			continue;
		}
		if(eql(u8, cmd, "export-gv")) {
			const a = try getArgs(stdout, args, .{[]const u8, ?bool}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be exported.\n", .{});
				continue;
			}
			var file = std.fs.cwd().createFile(a[0], .{}) catch {
				try stdout.print(color.red++"Could not open file '{s}'.\n", .{a[0]});
				continue;
			};
			defer file.close();
			const writer = file.writer();
			try writer.print("digraph codevolution{{", .{});
			for(gen.?.roots) |r|
				try r.graphviz(writer, a[1] == null or a[1].?);
			try writer.print("}}", .{});
			try stdout.print("Exported graph to file '{s}'.\n", .{a[0]});
			continue;
		}
		if(eql(u8, cmd, "export-stats")) {
			const a = try getArgs(stdout, args, .{[]const u8}) orelse continue;
			if(gen == null) {
				try stdout.print(color.red++"A generation must be created before it can be exported.\n", .{});
				continue;
			}
			var file = std.fs.cwd().createFile(a[0], .{}) catch {
				try stdout.print(color.red++"Could not open file '{s}'.\n", .{a[0]});
				continue;
			};
			defer file.close();
			const stats = gen.?.stats();
			try std.json.stringify(stats, .{}, file.writer());
			continue;
		}
		if(eql(u8, cmd, "help")) {
			_ = try getArgs(stdout, args, .{}) orelse continue;
			inline for(.{
				.{"help", "", "Displays this help info."},
				.{"new", "[population = 1000]", "Starts a new simulation with [population] programs."},
				.{"seed", "[seed]", "If [seed] is specified, sets the seed to [seed]. Otherwise prints current seed."},
				.{"next", "[iterations = 1]", "Performs [iterations] iterations."},
				.{"ls", "[count = 30]", "Lists the top [count] programs."},
				.{"out", "<name> [ascii]", "Prints the output for program <name>. If [ascii] is set to true, it prints it out as an ASCII-encoded string. If it is set to false, it prints it as a sequence of numbers. By default, it selects which of these modes makes most sense for the given goal."},
				.{"goal", "[goal]", "If [goal] is specified, sets the goal to [goal]. Otherwise prints current goal."},
				.{"goals", "", "Lists available goals."},
				.{"clear", "", "Clears the terminal."},
				.{"stats", "", "Prints statistics about the current generation."},
				.{"optmem", "<enabled>", "Enable/disable memory optimization mode. When this is enabled, lineages are not stored, and only currently alive programs may be viewed. Recommended for low-memory systems, or for running automated testing where this isn't needed."},
				.{"export-gv", "<file> [prune = false]", "Exports a graph of generations to a graphviz-formatted file. If [prune] is enabled, it removes programs with no offspring."},
				.{"export-stats", "<file>", "Exports statistics about the current generation to a JSON-formatted file."}
			}) |c| {
				try stdout.print(color.green++c[0]++color.magenta++(if(c[1].len != 0) " "++c[1]++" " else " ")++color.white++"- "++c[2]++"\n", .{});
			}
			try stdout.print(color.yellow++"NOTE: Many settings only take effect after `new` is run again.\n", .{});
			continue;
		}
		try stdout.print(color.red++"Unrecognized command '{s}'.\n", .{cmd});
	}
}

/// Gets arguments of command. Returns null if argument parsing failed.
fn getArgs(output: anytype, strings: [][]const u8, comptime args: anytype) !?std.meta.Tuple(&args) {
	// assuming args is a tuple of types
	var ret: std.meta.Tuple(&args) = undefined;
	const len = comptime blk: {
		for(@typeInfo(@TypeOf(args)).Struct.fields, 0..) |f, i| {
			if(@typeInfo(@field(args, f.name)) == .Optional)
				break :blk i;
		}
		break :blk ret.len;
	};
	if(strings.len < len or strings.len > args.len) {
		try output.print(color.red++"Incorrect number of arguments.\n", .{});
		return null;
	}
	inline for(@typeInfo(@TypeOf(args)).Struct.fields, 0..) |f, i| {
		if(i >= strings.len) {
			if(@typeInfo(@field(args, f.name)) == .Optional)
				ret[i] = null;
		} else {
			comptime var T = @field(args, f.name);
			if(@typeInfo(T) == .Optional)
				T = @typeInfo(T).Optional.child;
			const info = @typeInfo(T);
			if(info == .Int) {
				const int = std.fmt.parseInt(T, strings[i], 10) catch {
					try output.print(color.red++"'{s}' can not be parsed as {}.\n", .{strings[i], T});
					return null;
				};
				ret[i] = int;
			}
			else if(info == .Float) {
				const float = std.fmt.parseFloat(T, strings[i]) catch {
					try output.print(color.red++"'{s}' can not be parsed as {}.\n", .{strings[i], T});
					return null;
				};
				ret[i] = float;
			}
			else if(T == []const u8) {
				ret[i] = strings[i];
			}
			else if(T == bool) {
				if(eql(u8, strings[i], "true")) {
					ret[i] = true;
				} else if(eql(u8, strings[i], "false")) {
					ret[i] = false;
				} else {
					try output.print(color.red++"'{s}' must be either true or false.", .{strings[i]});
					return null;
				}
			}
			else
				@compileError("Type "++@typeName(f.type)++" unsupported.");
		}
	}
	return ret;
}
