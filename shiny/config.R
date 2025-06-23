# Configuration file for the variant voting app

## Database configuration

### file paths
cfg_to_be_voted_images_file <- "./screenshots/uro003_paths_mock.txt"
cfg_sqlite_file <- "./screenshots/annotations.sqlite"

### database columns
cfg_db_general_cols <- c("coordinates", "REF", "ALT", "variant", "path")

cfg_vote2dbcolumn_map <- list(
  yes = "vote_count_correct",
  no = "vote_count_no_variant",
  diff_var = "vote_count_different_variant",
  not_confident = "vote_count_not_sure"
)

cfg_vote_counts_cols <- c(
  unlist(cfg_vote2dbcolumn_map, use.names = FALSE), 
  "vote_count_total"
)

cfg_db_cols <- c(
  cfg_db_general_cols, 
  cfg_vote_counts_cols
)

## Login UI
cfg_institute_ids <- (c(
  "CNAG",
  "DKFZ",
  "DNGC",
  "FPGMX",
  "Hartwig",
  "ISCIII",
  "KU Leuven",
  "Latvian BRSC",
  "MOMA",
  "SciLifeLab",
  "Universidade de Aveiro",
  "University of Helsinki",
  "University of Oslo",
  "University of Verona"
))

cfg_institute_ids <- c("Training_answers_not_saved", cfg_institute_ids)

passwords <- c(
  "Test" = "1234",
  "Test2" = "1plusmg",
  "Training (answers won't be saved)" = "1plusmg"
)
cfg_user_ids <- names(passwords)

## Voting UI
### Options when the radio button I'm not sure [4] is selected
cfg_observations_dict <- c(
  "Issues with coverage" = "coverage",
  "Low allele frequency" = "low_vaf",
  "Alignment issues" = "alignment",
  "Complex event" = "complex",
  "Quality issues with the image" = "img_qual_issue",
  "Issue with the voting platform" = "platform_issue"
)

### Colors for the nucleotides
cfg_nt2color_map <- c(
  "T" = "#E31A1C", # Red
  "C" = "#1F78B4", # Blue
  "A" = "#33A02C", # Green
  "G" = "#FF7F00", # Orange
  "-" = "black"    # Black for gaps
) 

### user annotations file column names
cfg_user_annotations_colnames <- c(
   "coordinates", 
   "agreement", 
   "alternative_vartype",
   "observation",
   "comment"
)