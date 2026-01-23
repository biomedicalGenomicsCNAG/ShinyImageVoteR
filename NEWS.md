ShinyImgVoteR 0.1.2 (Development)
================

## Features

* Added on-demand database update (of the annotations table) for admin users
  - Admin users can update the database by clicking the "Update Database" button in the admin panel
  - When clicked, the system reads the to_be_voted_images_file (configured in config.yaml)
    and updates the database annotations table accordingly
  - Admin users receive immediate feedback via a modal dialog showing counts for added/updated/removed rows
  - Missing image paths in newly added or updated rows show a error message in the modal dialog

ShinyImgVoteR 0.1.1
================

## Bug Fixes

* Fixed database query logic to handle duplicate coordinates with different REF/ALT alleles
  - Updated `query_annotations_db_by_coord()` to accept REF and ALT parameters
  - Added configurable query keys via `db_query_keys` in config.yaml
  - Updated all database UPDATE queries to include REF and ALT in WHERE clauses
  - Added REF and ALT to user annotations file for proper variant identification
  - Updated test suite to verify querying with duplicate coordinates works correctly
  
* Fixed not working folder creation when new users are added via the user creation admin table
  - Added a create_user_directory function inside a tryCatch block logging errors

* Fixed leaderboard not showing all groups
  - Before the leaderboard was populated based on the institutes2userids2passwords file,
    now the institutes are fetched from the database

## Features

* Added fullscreen overlay 
  - Can be toggled via the ⛶ button in the top-left corner of the screenshot area or via double-clicking the screenshot
  - In fullscreen mode, the screenshot area expands to fill the entire browser window 
    it can be closed by clicking the "Exit Fullscreen" button in the top-right corner or
    via the "Esc" key on the keyboard
  - Note, in the fullscreen overlay pan/zoom functionalities and
    the voting/navigation hotkeys are disabled

* Added configurable maximum matching votes per screenshot across all users 
  - It can be set via `voting_options_max_matching_votes` in config.yaml
  - Default is 3 votes for each option if not specified
  - If maximum matching votes reached for a screenshot, it will be skipped for future users
  - Skipped screenshots are logged in user annotations file with reason "skipped - max matching votes (x) for option (y) reached" in the agreement column

* Enhanced the leaderboard
  - Added the columns "skipped images" and "unique_images_voted"
  - Admins can expand institutes to see per-user voted/skipped image counts

* Enhanced user creation admin table
  - Table no longer only serves the purpose of showing the users which have not yet  accessed their password retrieval link but now shows all users
  - Added action button to reset all the annotations of a user

ShinyImgVoteR 0.1.0
================

Initial version.