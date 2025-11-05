# Command Line Interface

The command line interface allows you to interact with, create and edit `.esm` files. The functions are documented here and can also be seen by using `esm -h`. The help for each function can be seen by using `esm summarise -h` or `esm template -h` for example.

## summarise

A typcial working begins with `esm summarise`, which lets you view your raw data. This can be helpful for decisions such as detecting contamination in blank wells, gating, etc.

```@docs; canonical=false
ESM.summarise
```

## template

To convert and collect your data into a `.esm` file, you first want to create an Excel file that describes your data and how it should be imported, processed and viewed. A template Excel file can be loaded using the `esm template ...` function. To see how the Excel file should be filled out, check out [Getting Started with ESM](@ref) or [Excel Interface](@ref).

```@docs; canonical=false
ESM.template
```

## translate

Once the template has been filled out and completed, it can be translated into a `.esm` file using the `esm translate ...` function.

```@docs; canonical=false
ESM.translate
```

## views

To create the views from a `.esm` file, you can use the `esm views ...` function. This saves the views as `.csv` files or plots relevant figures.

```@docs; canonical=false
ESM.views
```
