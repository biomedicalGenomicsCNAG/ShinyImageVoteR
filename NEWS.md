ShinyImgVoteR 0.1.1 (Development)
================

## Bug Fixes

* Fixed database query logic to handle duplicate coordinates with different REF/ALT alleles
  - Updated `query_annotations_db_by_coord()` to accept REF and ALT parameters
  - Added configurable query keys via `db_query_keys` in config.yaml
  - Updated all database UPDATE queries to include REF and ALT in WHERE clauses
  - Added REF and ALT to user annotations file for proper variant identification
* Updated test suite to verify querying with duplicate coordinates works correctly

ShinyImgVoteR 0.1.0
================

Initial version.