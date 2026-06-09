# Other Useful Functions

There are a couple more functions in ESM that may be generally useful for plate reader data. These are the `at` and `between` functions (and there sister functions `at_time` and `between_times`).

```@docs
ESM.at
ESM.between
ESM.at_time
ESM.between_times
```

They allow you to remove elements of your data (say removing low OD values to avoid returning a growth rate at low OD when the data is very noisy).

```@setup data
using ESM
using DataFrames

out, _ = ESM.read("../../../test/inputs/biotek-data.csv", BioTek())
od = out["OD_600"]
flu = out["GFP_485_530"]
od_times = od[:, [:time]]
od = od[:, Not([:time, :temperature])]
flu_times = flu[:, [:time]]
flu = flu[:, Not([:time, :temperature])]
rename!(lowercase, od)
rename!(lowercase, flu)
```

We have a dataset contaning fluorescence (`flu` and `flu_times`) and optical density (`od` and `od_times`).

```@repl data
flu
flu_times
od
od_times
```

## The at\_time and between\_times functions

The first thing we will look at is how to index the data by time. Below, we will access the od data at 5 minutes and then all of the od data between 3 and 24 minutes.

```@repl data
at_time(od, od_times, 5)
between_times(od, od_times; min_value = 3, max_value = 24)
```

For `at_time`, we returned a single row data frame with the `od` data at 5 minutes (techinically the last recording before 5 minutes).

For `between_times`, all data that was recorded before 3 minutes and after 24 minutes was set to `missing`. This means it will be ignored by most functions in ESM.

## The at function

Next, we will look at the more general `at` function. We will use it to get the time when the OD is 0.5 for well A2.

```@repl data
at(od_times, od[:, [:a2]], 0.5)
```

We can also use it to get the OD for all wells, when the OD for well A2 is 0.5.

```@repl data
at(od, od[:, [:a2]], 0.5)
```

Finally, we could use it to get the fluorescence for each well when the OD of that well is 0.5. Note that some wells (like A1) are blanks and won't reach 0.5, so the last recording will be used.

```@repl data
at(flu, od, 0.5)
```

This final version requires a few assumptions. It requires that the column names of the two data frames (`od` and `flu`) match. It also assumes that the columns are recorded at roughly the same time.

!!! note "Thinking about monotonicity"
    Since we are finding the last row index where OD≤0.5, if OD decreases later on in the experiment and drops below 0.5, we might return that row instead. It's common for OD data to be non-monotonic (both increasing and decreasing at different times). If this is a problem, it may be worth first using `between_times` to reduce the data to a monotonic subset.

## The between function

Finally, we will look at the general `between` function. It provides a similar interface to the `at` function, returning a data frame where values outside the range are set to `missing`.

```@repl data
between(od_times, od[:, [:a2]]; min_value=0.125, max_value=0.8)
between(od, od[:, [:a2]]; min_value=0.125, max_value=0.8)
between(flu, od; min_value=0.125, max_value=0.8)
```

There is also a simpler way to reduce the OD data to between two thresholds by only providing the `od` data frame.

```@repl data
between(od; min_value=0.1, max_value=0.8)
```
