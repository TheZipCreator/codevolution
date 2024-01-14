## General
It seems that mutation rate is best when it's put at 100%. This is because I think there's sort of a "soft mutation rate"; i.e. the percentage of mutations that don't do anything. They don't do anything since around half of each program appears to be garbage (as in, instructions that don't do anything or affect the result), and mutating that does nothing to the fitness of the program.

Generation size also doesn't seem to have a large effect on fitness over time, but that needs more testing.

## `print1`
Programs seem to do well in this challenge, but on most trials they cap out at 500 (with programs that are mostly just loops of `out 1` followed by a jump back), which I thought was an optimal score, until in one trial one program went to 667. Looking at it, it outputted *twice* before jumping back. I haven't been able to replicate this again.

In one trial, there was a program like so (generation #31):
```asm
  in r2
A out 1
  mov r1, r7
  out 1
  jmp A
  ...
```
which got a score of 500. Note how that's despite there being two `out`s. This is different from the usual program that shows up around this generation, which usually has just one `out`. Within 2 generations, the extraneous `mov` was removed, achieving a fitness of 66.

## `hello-world`
Compared to `print1`, the program struggles a bit more at this one. I think it might be better if I somehow added some leniency to the Levenshtein Distance (e.g. subsitutions of characters that have closer ascii values to other characters cost less), so I'll probably try that.

It takes hundreds of generations to get good results, but the upside is that running generations doesn't take much time with this goal. I believe that's because most of the programs are linear in nature and end rather quickly, unlike other goals where loops improve fitness.

I notice that with this goal, programs tend to have a bunch of useless garbage in them. I believe that's because there's no incentive to really have less instructions; the amount of cycles used to print "Hello, World!" isn't particularly important, as long as it gets printed.

## `increasing`
My hope with this one is that it'd use the `add` instruction to generate a sequence of increasing integers, but alas, no. It instead just hardcoded sequences of increasing integers.

## `cat`
The program does astonishingly well at this one. Within just 10 or so generations it manages to get fitness all the way to `-2`.

I noticed that in one trial, there was one program like so:
```asm
  out r0
A in r2
  out r2
  in r3
  mov r6, 32
  out r3
  jmp A
  ...
```
which catted twice. Due to the way I'm scoring this (levenshtein distance from an input), I think this scores lower than just doing it once (since at some point it's just printing zeroes, which do not exist in the original input).

## `double`
It really struggles on this one. It can't seem to realize it needs to multiply the input by two. I think I'm gonna modify the levenshtein distance to take into account the ASCII distance between characters
