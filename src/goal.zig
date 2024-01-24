//! Contains goals for the programs to accomplish

const std = @import("std");
const Random = std.rand.Random;
const Allocator = std.mem.Allocator;

const Program = @import("program.zig").Program;

const Generation = @import("generation.zig").Generation;

const color = @import("color.zig").color;

/// A goal
pub const Goal = struct {
	name: []const u8,
	desc: []const u8,
	input: ?*const fn(Allocator, Random) anyerror![]const u8 = null, // returned slice is owned by the caller and must be freed
	fitness: *const fn(Program) i64,
	outputAsString: bool = false, // whether output is a string (for ease of use)

	pub fn write(self: Goal, writer: anytype) !void {
		try writer.print(color.green++"{s}\n"++color.default, .{self.name});
		try writer.print("{s}\n", .{self.desc});
	}
};

/// Levenshtein distance
fn stringDist(s: []const u8, t: []const u8) usize {
	// mostly stolen from https://en.wikipedia.org/wiki/Levenshtein_distance and ziggified
	const baseCost = 16;
	var v0 = comptime init: {
		var ret: [Generation.numCycles]usize = undefined;
		for(0..Generation.numCycles) |i|
			ret[i] = baseCost*i;
		break :init ret;
	};
	var v1 = [_]usize { 0 } ** Generation.numCycles;
	for(0..s.len) |i| {
		v1[0] = baseCost*(i+1);
		for(0..t.len) |j| {
			const deletionCost = v0[j+1]+baseCost;
			const insertionCost = v1[j]+baseCost;
			const subsitutionCost = v0[j]+@abs(@as(i16, @intCast(s[i]))-@as(i16, @intCast(t[j])));
			// const deletionCost = v0[j+1]+1;
			// const insertionCost = v1[j]+1;
			// const subsitutionCost = if(s[i] == t[j]) v0[j] else v0[j]+1;
			v1[j+1] = @min(deletionCost, @min(insertionCost, subsitutionCost));
		}
		// swap v0 with v1
		for(&v0, &v1) |*a, *b|
			std.mem.swap(usize, a, b);
	}
	return v0[t.len];
}

// test "string distance" {
// 	std.debug.print("\n", .{});
// 	std.debug.print("{d}\n", .{stringDist("Hello, World!", "elm!")});
// 	std.debug.print("{d}\n", .{stringDist("Hello, World!", "flm!")});
// 	std.debug.print("{d}\n", .{stringDist("Hello, World!", "")});
// 	std.debug.print("\n", .{});
// }

fn print1(p: Program) i64 {
	var ret: i64 = 0;
	for(p.output.items) |b| {
		if(b == 1)
			ret += 1;
	}
	return ret;
}

fn helloWorld(p: Program) i64 {
	return -@as(i64, @intCast(stringDist("Hello, World!", p.output.items)));
}

fn increasing(p: Program) i64 {
	if(p.output.items.len == 0)
		return 0;
	var ret: i64 = 0;
	var last: u8 = p.output.items[0];
	for(p.output.items) |b| {
		ret += if(b > last) 1 else -1;
		last = b;
	}
	return ret;
}


fn randomInput(ally: Allocator, rng: Random) ![]const u8 {
	const str = try ally.alloc(u8, Generation.numCycles/3); // the minimum program is smth like input -> output -> repeat, which is 3 cycles per char
	for(str) |*c|
		c.* = rng.int(u8);
	return str;
}

fn catFitness(p: Program) i64 {
	return -@as(i64, @intCast(stringDist(p.input, p.output.items)));
}

fn doubleFitness(p: Program) i64 {
	var doubled: [Generation.numCycles/3]u8 = undefined;
	for(&doubled, 0..) |*d, i|
		d.* = p.input[i]*%2;
	return -@as(i64, @intCast(stringDist(&doubled, p.output.items)));
}

/// Existing goals
pub const goals = .{
	.print1 = Goal {
		.name = "print1",
		.desc = "Print as many ones as possible. Fitness is how many ones are outputted.",
		.fitness = &print1
	},
	.helloWorld = Goal {
		.name = "hello-world",
		.desc = "Print the string 'Hello, World!'. Fitness is the negative levenshtein distance.",
		.fitness = &helloWorld,
		.outputAsString = true
	},
	.increasing = Goal { 
		.name = "increasing",
		.desc = "Have increasing strings of numbers, for as long as possible. Every successive increase is a +1 to fitness, and every successive decrease is a -1.",
		.fitness = &increasing 
	},
	.cat = Goal {
		.name = "cat",
		.desc = "Input should be the same as output. Fitness is measured by the negative levenshtein distance between the input and output.",
		.input = &randomInput,
		.fitness = &catFitness
	},
	.double = Goal {
		.name = "double",
		.desc = "Values in the output should be twice those in the output. Fitness is measured by the negative levenshtein distance between the input and output.",
		.input = &randomInput,
		.fitness = &doubleFitness
	}
};
