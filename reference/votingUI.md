# Voting module UI

Provides the user interface for displaying a voting task, including:

- An image of a candidate somatic mutation

- A radio button to express agreement with the annotation

- Conditional inputs for alternate mutation type and comments

- Navigation controls (Back / Next)

## Usage

``` r
votingUI(id, cfg)
```

## Arguments

- id:

  A string identifier for the module namespace.

## Value

A Shiny UI element (`fluidPage`) representing the voting interface.

## Details

This module uses `shinyjs` for interactivity and includes a custom
`hotkeys.js` script to enable keyboard shortcuts (e.g., Enter for
"Next", Backspace for "Back").

The displayed options and labels are configured using:

- `cfg$radioBtns_label`

- `cfg$radio_options2val_map`

- `cfg$checkboxes_label`

- `cfg$observations2val_map`

These should be defined in a sourced configuration file (config.yaml).
