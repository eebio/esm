using KernelDensity, Plots, StatsBase, FileIO

# Step 1: Generate some 2D data
file=load("../example/20191121_FLOPR_EXAMPLE/20191121_beads.fcs")
# print([bitstring(i) for i in file.data["FSC-A"]])
print(file.params)
# m=[m for m in file["TIME"]] 
# print(m)
x = [i for i in file["FSC-A"]]
y = [i for i in file["SSC-A"]]  # Introduce some correlation
z = [i for i in file["BL1-H"]]
print(length(z))
# print(x,y,z)
# print(x)
at=[4.0,1.0]
r=1048576
amp(k)=at[2]*10 ^(at[1]*(k/r))

# x=amp.(x)
# y=amp.(y)
# z=amp.(z)
# print(x[end])
# print(amp([1024],[4.0,1,0],1024))
# print(x)
# maxr=amp(1024)
maxr=r
dat_mask=[1 < xi < maxr && 1 < yi < maxr && 1 < zi < maxr for (xi, yi,zi) in zip(x, y,z)]
# print(dat_mask)

x=[xi for (xi, m) in zip(x, dat_mask) if m]
# print(x)
y=[yi for (yi, m) in zip(y, dat_mask) if m]
z=[zi for (zi, m) in zip(z, dat_mask) if m]
N=length(x)
# Step 2: Create a 2D histogram (for bin edges reference)
# hist_bins = (-3:0.2:3, -3:0.2:3)  # Define histogram bins
hist_counts = fit(Histogram, (x, y); nbins=1024)  # Compute histogram

# fraction_to_keep = 0.75  # Keep top 20% of highest density points
# sorted_indices = sortperm(hist_counts.weights, rev=true,dims=1)
# top_indices = sorted_indices[1:ceil(Int, fraction_to_keep * N)]
# x_top = x[top_indices]
# y_top = y[top_indices]

# Step 3: Define histogram bin edges
x_bins = hist_counts.edges[1]
y_bins = hist_counts.edges[2]
hist_bins=(x_bins,y_bins)
# print(collect(hist_bins[1]))

# Step 4: Compute KDE for the data
kd = kde((x, y),bandwidth=(0.5,0.5))#,bandwidth=(0.1,0.1))  # Use KernelDensity for 2D KDE

# Step 5: Evaluate the KDE at each data point
density_values = [pdf(kd, xi, yi) for (xi, yi) in zip(x, y)]
# density_values = pdf.(kd, x',y) 
# density_values ./= sum(density_values)
# print(maximum(density_values))

# Step 6: Define a threshold and filter points (points inside KDE contour)
fraction_to_keep = 0.75  # Keep top 20% of highest density points
sorted_indices = sortperm(density_values, rev=true)
top_indice = sorted_indices[ceil(Int, fraction_to_keep * N)]
# print(density_values[top_indice])
threshold = density_values[top_indice]  # Define a density threshold
inside_indices = density_values .> threshold  # Points inside the contour
# print(inside_indices)
x_inside = x[inside_indices]
y_inside = y[inside_indices]

# Step 7: Identify points outside the histogram bins
inside_bins = (x .>= minimum(x_bins)) .& (x .<= maximum(x_bins)) .& (y .>= minimum(y_bins)) .& (y .<= maximum(y_bins))
x_outside = x[inside_bins]
y_outside = y[inside_bins]

# Step 8: Define a fraction of values to retain inside the KDE contour
# fraction_to_keep = 0.75  # Keep top 20% of highest density points
# sorted_indices = sortperm(density_values, rev=true)
# top_indices = sorted_indices[1:ceil(Int, fraction_to_keep * N)]
# x_top = x[top_indices]
# y_top = y[top_indices]

# Step 9: Plot filtered points and contours
# histogram2d(x_outside, y_outside, label="Points outside histogram bins",xscale=:log10,yscale=:log10)
# histogram2d!(x_inside, y_inside, label="Points inside KDE contour (top 20%)", title="Filtered Points Inside KDE Contour",xscale=:log10,yscale=:log10)
xlabel!("x")
ylabel!("y")
arr=10.0 .^range(0,7,length=255)
stephist(z,bins=arr,color=:steelblue1, alpha=0.4, xscale=:log10,seriestype=:stephist)

stephist!(z[inside_indices],bins=arr,xscale=:log10,color=:steelblue1,seriestype=stephist)

# Optional: Overlay KDE contour for reference
# contour!(kd.density)


# x_grid = 10 .^ range(0, 4, length=500)  # Logarithmic spacing
# y_grid = 10 .^ range(0, 4, length=500)
# kde_grid_values =  [pdf(kd, yi, xi) for xi in x_grid, yi in y_grid] # KDE over a grid
# print(kde_grid_values)
# contour!(x_grid, y_grid, kde_grid_values, levels=[threshold], color=:red, linewidth=2, label="KDE Contour",xscale=:log10,yscale=:log10)



# Step 10: Plot the points outside the histogram bins
plot!(minorgrid=true,legend=false)
xlims!(1e+0, 1e+7)
# ylims!(1e+0, 1e+4)

#"#WINEXT" => "0", "\$P3R" => "1048576", "\$BTIM" => "16:45:41", "\$CYTSN" => "2AFC210781115", "\$P4S" => "BL1-A", "\$ENDSTEXT" => "000000000000", "\$P4N" => "BL1-A", "#LASER4DELAY" => "375", "\$TIMESTEP" => "0.001", "#P1TARGET" => "NA", "\$FIL" => "beads.fcs", "#LASER3COLOR" => "Violet", "\$P7F" => "530", "\$P2R" => "1048576", "\$P6S" => "SSC-H", "#WIDTHTHRESHOLD" => "1000", "\$P8V" => "340", "\$CELLS" => "NA", "\$P1E" => "0,0", "#LASER1COLOR" => "Blue", "\$VOL" => "40000", "\$PAR" => "10", "\$P4R" => "1048576", "\$P4L" => "488", "\$P1L" => "NA", "\$SMNO" => "control", "#LASER2ASF" => "1.11", "\$P10E" => "0,0", "\$P10B" => "32", "#LASER1DELAY" => "1100", "\$LAST_MODIFIER" => "crobinson", "\$P9N" => "SSC-W", "\$P6V" => "360", "\$P3E" => "0,0", "\$P10F" => "530", "#TR1" => "AND_FSC,2000", "\$P2B" => "32", "\$LOST" => "0", "\$P2S" => "FSC-A", "\$P3S" => "SSC-A", "\$P5B" => "32", "\$P5S" => "FSC-H", "\$DATE" => "21-Nov-2019", "\$P5E" => "0,0", "\$P7L" => "488", "\$P7N" => "BL1-H", "\$P3L" => "488", "\$NEXTDATA" => "000000000000", "\$P3N" => "SSC-A", "#TR2" => "AND_SSC,1000", "\$P2N" => "FSC-A", "\$P4F" => "530", "\$P2V" => "340", "\$P3B" => "32", "\$ETIM" => "16:46:05", "#LASER1ASF" => "1.08", "\$P10N" => "BL1-W", "\$P9S" => "SSC-W", "\$P1S" => "Time", "\$P7V" => "345", "\$P8N" => "FSC-W", "\$P9E" => "0,0", "\$P1F" => "NA", "\$P6L" => "488", "\$P9V" => "360", "\$P6B" => "32", "\$SYS" => "OPTIXE2 Microsoft Windows 7 Professional ", "\$P3F" => "488", "#LASERCONFIG" => "BRVY", "\$P5F" => "NA", "\$P5N" => "FSC-H", "\$P2F" => "NA", "\$P6N" => "SSC-H", "\$EXP" => "NA", "\$P2E" => "0,0", "#LASER2DELAY" => "1486", "\$P8E" => "0,0", "\$P1B" => "32", "\$TOT" => "14106", "\$P8F" => "NA", "\$OP" => "clare robinson", "\$P6F" => "488", "\$P1N" => "Time", "#LASER3ASF" => "1.05", "#PTDATE" => "21-Nov-2019", "#LASER4COLOR" => "Yellow", "\$P4B" => "32", "\$P7S" => "BL1-H", "\$P7R" => "1048576", "\$P7E" => "0,0", "\$P8R" => "1024", "\$ENDANALYSIS" => "000000000000", "\$P10L" => "488", "\$P4V" => "345", "\$SRC" => "NA", "\$P8B" => "32", "\$CYT" => "4486521 Attune NxT Acoustic Focusing Cytometer (Lasers: BRVY)", "\$P2L" => "488", "\$ORIGINALITY" => "NonDataModified", "\$PLATENAME" => "2019_11_21_consGFP", "\$SPILLOVER" => "3,BL1-A,BL1-H,BL1-W,1.000000,0.000000,0.000000,0.000000,1.000000,0.000000,0.000000,0.000000,1.000000", "\$P5R" => "1048576", "\$INST" => "NA", "\$P3V" => "360", "#LASER3DELAY" => "756", "\$P5L" => "488", "\$P6E" => "0,0", "\$P7B" => "32", "\$P10R" => "1024", "\$P8S" => "FSC-W", "#LASER2COLOR" => "Red", "\$P9B" => "32", "#LASER4ASF" => "1.05", "#P1LABEL" => "NA", "\$P1R" => "67108864", "\$PROJ" => "2019_11_21_consGFP", "\$P10S" => "BL1-W", "\$P5V" => "340", "#FLOWRATE" => "100", "\$P6R" => "1048576", "\$ENDDATA" => "000000572431", "\$BYTEORD" => "1,2,3,4", "\$P10V" => "345", "\$DATATYPE" => "F", "\$P8L" => "488", "\$BEGINSTEXT" => "000000000000", "\$P4E" => "0,0", "\$P9R" => "1024", "\$LAST_MODIFIED" => "25-Nov-2019 09:28:47", "\$P1V" => "NA", "\$P9F" => "488", "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      " => "", "#PTRESULT" => "Pass", "\$BEGINDATA" => "000000008192", "" => "10", "\$P9L" => "488", "\$BEGINANALYSIS" => "000000000000", "\$COM" => "NA", "\$MODE" => "L")