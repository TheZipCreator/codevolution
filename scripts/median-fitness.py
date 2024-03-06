#!/usr/bin/python3

# Creates a histogram of median fitness after a given number of generations for a given goal

import numpy as np;
import subprocess;
import json;
import seaborn as sns;
import math;
import matplotlib.pyplot as plt;
import pandas as pd;

generations = 20;
goal = "print1";


trials = 100;

data = [];

for i in range(trials):
    filename = f"data/trial-{i}.json";
    subprocess.run(["./zig-out/bin/codevolution"], input=f"optmem true\nnew\ngoal {goal}\nnext {generations}\nexport-stats {filename}\nexit".encode("utf-8"));
    with open(filename) as f:
        stats = json.load(f);
        data.append(stats["fitness"]["median"]);

ax = sns.histplot(data=data, binwidth=100);
ax.set(xlabel="Fitness", ylabel="Count");
plt.show();
