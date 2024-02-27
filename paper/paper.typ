#align(center)[
	#text(size: 16pt)[
		= CODEVOLUTION
		Can Genetic Algorithms Write Code?
	]

	_name omitted_
]

#let inline-num(n) = {
	numbering("(i)", n);
}

#set raw(syntaxes: "codevolution.yml")

#columns(2)[
= Abstract
In this paper, I showcase an algorithm written for generating code in a custom Assembly-like programming language. This algorithm is given a specific goal, which consists of a generated input and an expected output (measured by a fitness function). It is then able to, via a genetic algorithm, improve randomly generated code into code that can achieve the set goal.

*Keywords:* Genetic Programming, Genetic Algorithm, Code Generation, Assembly

= Introduction
Genetic Algorithms are search and optimization algorithms inspired by the principles of Natural Selection.@genetic-algorithm They consist of a number of individuals, comprising a population. Each of these individuals has some sort of _genome_, which determines how they act, and over time the algorithm fine tunes that genome to achieve certain results. The algorithm used in this paper consists of three main steps: #inline-num(1) the evaluation of individuals based on how well they perform at the given task (the _fitness function_), #inline-num(2) the elimination of the worst-performing individuals (_selection_), and #inline-num(3) the random altering of those individuals (_mutation_). One of these cycles is called a _generation_. The hope is that, over time, as more generations are run and as more possibilities are explored, the individuals will get better at their specified task. For this specific experiment, a few different tasks were used in different trials; each of these tasks entail performing an algorithm of some kind. For example, in one trial individuals were expected to output as many of the ASCII character `1` as possible, while in another trial individuals were expected to directly copy their input to their output.

= Model
Each individual (hereby referred to as a _program_) consists of a series of instructions (this is their genome). This instruction-based approach differs from more common grammar-based approaches, such as the one seen in @grammar-based-gp. At the start of the trial, one thousand programs are generated at random, with lengths between five and ten (inclusive).  Every program in the population is run for exactly one thousand cycles (each cycle corresponding to a single instruction being run) before being forcibly terminated, however they may halt on their own before that point. Programs are given an input and an output, and are expected to produce a certain output given a certain input. Once all programs in a generation are run, they are scored by the fitness function, which compares each program's output to the expected output, in a manner dependent on the task. The lowest-ranking half of programs are then discarded, and the remaining programs are reproduced into their place, with mutations applied.
== Architecture
There are two buffers, the input buffer, and the output buffer. Both are composed of bytes, and programs may read from the input buffer, and write to the output buffer (the input buffer can be thought of as a queue, while the output buffer can be thought of as a stack).

Programs have ten registers. The first register is the instruction pointer (abbreviated as `ip`), which describes which instruction the program is currently on. If the instruction pointer becomes less than zero, it is reset to zero, and if it becomes more than the total length of the program, the program immediately halts. The next register is the location in the input buffer; when an `in` command is executed, this is advanced and the byte in the buffer corresponding to where it was is read. The previous two registers are 64-bit. The following eight registers (called _data registers_) are general-use and may be modified during runtime, and they are 8-bit. They are named `r0` through `r7`.
== Instruction Set
Below is a table of the instructions that programs were given. `reg` represents a data register, and `imm` represents an immediate value.
]
#columns(1)[
#table(
	columns: (50%, 50%),
	[*Instruction*], [*Effect*],
	[`mov <reg>, <reg | imm>`], [Moves a value into a register.],
	[`in <reg>`], [Takes a value from the input buffer, and stores it into a register.],
	[`out <reg | imm>`], [Outputs a value.],
	[`jmp <off>`], [Sets `ip` to `ip+<off>`, where `<off>` is a signed 64-bit integer. When displaying programs, the offsets are abstracted into labels to aide readability, so a jump might be displayed as `jmp A` (jump to label A), or possibly `halt` if it jumps pass the end of the program.],
	[`op <add | sub | mul | div>, <reg>, <reg | imm>`], [Performs the specified operation with the destination register and the value, and stores it in the destination register. When displaying programs, the `op` is omitted, and this is displayed as just the operation.]
)
]
#columns(2)[
== Mutation
A percentage of programs will have their offspring be mutated. This rate is named the _mutation rate_. When a program is mutated, one of the following mutations occur:
- An instruction is modified. (for example, the operation in an `op` instruction being changed, or an `out` now outputting from a register instead of from an immediate. Note that this does not change the opcode of the instruction, only the operations.)
- An instruction is replaced with a completely random instruction.
- Two instructions are swapped with eachother.
- An instruction is inserted at a random location. Jump targets are modified such that they point to the same instruction they did previously.
- An instruction is removed. Jump targets are altered as previously described.
== Fitness Function Design
The performance for any genetic algorithm is highly dependent on the design of the fitness function. In @fitness-function-design, the authors lay out a few basic principles for the design of a fitness function. Namely, for this experiment: #inline-num(1) try to convert _phenotypic_ requirements (in our case, that's requirements of what the program outputs) to _genotypic_ requirements (in our case, requirements on what the program's code should look like), and #inline-num(2) transform decision requirements (e.g. requirements that look like a yes/no question) into optimization requirements (e.g. ones where you can "grade" based on intermediate levels of satisfaction). Of these, #inline-num(2) was done most in the design of the fitness functions used for this experiment, as just a pure yes/no question does not allow gradual improvement, and that is necessary for a genetic algorithm.
= Results
For many of the tasks given, the algorithm did a decent job of creating a program to perform it, but some tasks were problematic. This reflects the difficulty of designing adequate fitness functions for tasks, as it is difficult to express a problem in a way that is conducive to genetic algorithms. Below is a list of every task attempted:
== Print `1`
The goal of this task was to print as many of the ASCII character `1` (e.g. the byte `31`) as possible. Fitness was defined as how many `1`s are left in the output buffer after the program is terminated. Programs did very well, achieving a median of 500 after 20 generations (as seen in @print1-fitness).
#figure(
	image("print1-fitness.svg"),
	caption: [Median fitness of 100 trials for goal `print1` after 20 generations.]
) <print1-fitness>
I thought the optimal score was 500, since that would be the score gotten by an `out 1` immediately followed by a jump back to the start. However, this was not the case, as a program could output twice before (or more!) before jumping back to the start, garnering a higher fitness (see @fitness-over-500), in effect unrolling a loop.
#figure(
	```cv
A out 1
  out 1
  jmp A
  in r7
	```,
	caption: [Program with fitness of over 500 (667).]
) <fitness-over-500>
== Cat
The goal of this task is to copy the input to the output (thereby mimicking the UNIX `cat` utility). Initially, fitness was measured by negative Levenshtein distance from the input to the output
#bibliography("scifair.bib")
]
