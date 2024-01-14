#!/usr/bin/python3

import numpy as np;
import subprocess;
import json;
import seaborn as sns;
import math;
import matplotlib.pyplot as plt;
import pandas as pd;


goal = "print1"

w = 5; 
h = 5;
size_step = 500;
mut_step = 15;
mut_start = 10;
generations = 50;

data = np.empty((w, h));



for i in range(0, w):
    for j in range(0, h):
        mut = mut_start+(i+1)*mut_step;
        size = (j+1)*size_step; 
        print(f"\nRunning with size={size} and mutation rate={mut}%\n");
        filename = f"./data/size{size}-mut{mut}.json";
        # subprocess.run(["./zig-out/bin/codevolution"], input=f"optmem true\ngoal {goal}\nmut {mut}\nnew {size}\nnext {generations}\nexport-stats {filename}\nexit".encode("utf-8"));
        with open(filename) as f:
            stats = json.load(f);
            data[i, j] = stats["fitness"]["median"];

df = pd.DataFrame(data, index=[mut_start+(i+1)*mut_step for i in range(w)], columns=[(i+1)*size_step for i in range(h)]);
ax = sns.heatmap(df, annot=True, fmt=".0f");
ax.set(xlabel="Population Size", ylabel="Mutation Rate");
ax.invert_yaxis();
plt.show();

