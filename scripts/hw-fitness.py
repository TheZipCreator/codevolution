#!/usr/bin/python3

import numpy as np;
import subprocess;
import json;
import seaborn as sns;
import math;
import matplotlib.pyplot as plt;
import pandas as pd;

numGenerations = 200;
numTrials = 10;

unadjustedFitness = np.empty((numGenerations, numTrials));
adjustedFitness = np.empty((numGenerations, numTrials));

def filename(adjusted, t, g):
    return "./data/"+("adjusted" if adjusted else "unadjusted")+"-"+str(t)+"-"+str(g);

# create stdin
stdin = "optmem true\ngoal hello-world-unadjusted\n";
for adjusted in [False, True]:
    if adjusted:
        stdin += "goal hello-world\n";
    for i in range(numTrials):
        stdin += "new\n"
        for j in range(numGenerations):
            stdin += f"export-stats {filename(adjusted, i, j)}\nnext\n"

# run process
subprocess.run(["./zig-out/bin/codevolution"], input=stdin.encode("utf-8"));

# get graph data
adjusted_data = np.zeros(numGenerations, dtype = np.int64);
unadjusted_data = np.zeros(numGenerations, dtype = np.int64);

for adjusted in [False, True]:
    array = adjusted_data if adjusted else unadjusted_data
    for i in range(numGenerations):
        for j in range(numTrials):
            with open(filename(adjusted, j, i)) as f:
                mean = json.load(f)["fitness"]["median"];
                array[i] += mean;
                
        array[i] /= numTrials;


# show graph
ax = sns.lineplot(data = pd.DataFrame({
    "Before Levenshtein Distance Change": unadjusted_data,
    "After Levenshtein Distance Change": adjusted_data
}), dashes=False);
ax.set(xlabel="Generation", ylabel="Fitness");
plt.show();
