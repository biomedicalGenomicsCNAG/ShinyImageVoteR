# Testing Checklist

This document provides a comprehensive checklist for testing the dynamic
database update feature.

## Prerequisites

R (version 4.5.0 or compatible) is installed

All package dependencies are installed (`make deps`)

Package is built and installed (`make install`)

## Automated Tests

### Unit Tests

Run the test suite to verify all unit tests pass:

``` bash
make test
```

Expected tests to pass: - \[ \]
`test-database-update.R::update_annotations_table adds only new entries` -
\[ \]
`test-database-update.R::update_annotations_table handles duplicate coordinates with different REF/ALT` -
\[ \]
`test-database-update.R::update_annotations_table handles missing file gracefully` -
\[ \]
`test-database-update.R::update_annotations_table processes paths correctly` -
\[ \] All existing tests continue to pass (no regressions)

### Test Coverage

Check that the new functionality has adequate test coverage:

``` bash
make coverage
```

Expected coverage: - \[ \]
[`update_annotations_table()`](https://biomedicalgenomicscnag.github.io/ShinyImageVoteR/reference/update_annotations_table.md)
function has \>80% coverage - \[ \] Overall package coverage remains
stable or improves

## Manual Testing

### Setup

Install and start the application:

``` bash
make install
make run
```

Verify the app starts successfully

Login with test credentials

Note the initial number of images available for voting

### Test Case 1: Add New Entries

Open the to_be_voted_images file:

``` bash
nano ./app_env/images/to_be_voted_images.tsv
```

Add one or more new entries (ensure coordinates/REF/ALT combination is
unique):

``` tsv
chr99:99999  A   G   app_env/images/screenshot_URO_003_mutations_varSorted_redoBAQ/test_new.png
```

Save the file

Wait approximately 5-10 seconds

Verify:

Console shows: “Added X new entries to annotations table”

User sees notification: “Database updated: X new entries added”

New images appear in the voting queue

### Test Case 2: Duplicate Prevention

Add entries that already exist in the file:

``` tsv
chr8:117226952   A   T   app_env/images/screenshot_URO_003_mutations_varSorted_redoBAQ/0a0b53acbf9fac0f45dfcf77a8c6baae.png
```

Save the file

Wait approximately 5-10 seconds

Verify:

Console shows: “No new entries found in to_be_voted_images_file”

No notification is shown to users

No duplicate entries in the database

### Test Case 3: Duplicate Coordinates with Different Alleles

Add an entry with the same coordinates but different REF/ALT:

``` tsv
chr8:117226952   G   C   app_env/images/screenshot_URO_003_mutations_varSorted_redoBAQ/different_mutation.png
```

Save the file

Wait approximately 5-10 seconds

Verify:

Console shows: “Added 1 new entries to annotations table”

User sees notification

New entry is added (not rejected as duplicate)

### Test Case 4: Multiple Concurrent Users

Open the app in multiple browser tabs/windows with different users

Add new entries to the file as in Test Case 1

Verify:

All users see the notification

New images become available to all users

### Test Case 5: Error Handling

Temporarily make the to_be_voted_images file unreadable:

``` bash
chmod 000 ./app_env/images/to_be_voted_images.tsv
```

Touch the file to update its modification time:

``` bash
touch ./app_env/images/to_be_voted_images.tsv
```

Wait approximately 5-10 seconds

Verify:

Console shows error message

User sees error notification

App continues to function normally

Restore file permissions:

``` bash
chmod 644 ./app_env/images/to_be_voted_images.tsv
```

### Test Case 6: Large File Updates

Add a large number of entries (e.g., 100+) to the file

Save the file

Wait for update to complete

Verify:

Update completes successfully

Notification shows correct count

App remains responsive

### Test Case 7: Continuous Operation

Leave the app running for an extended period (e.g., 30 minutes)

Periodically add new entries to the file

Verify:

File watcher continues to work reliably

No memory leaks or performance degradation

All updates are detected and processed

## Performance Testing

### Response Time

Measure time between file modification and notification:

- Expected: 5-10 seconds (5-second check interval + processing time)

Measure time to update database with different entry counts:

1 entry: \<1 second

10 entries: \<2 seconds

100 entries: \<5 seconds

### Resource Usage

Monitor memory usage during extended operation:

Memory usage remains stable (no leaks)

Monitor CPU usage:

Minimal CPU usage during idle (just periodic checks)

Acceptable CPU spike during update

## Edge Cases

File is deleted and recreated

File becomes empty

File contains malformed data

File contains columns in different order

File contains extra columns

File contains missing columns

Very large file (1000+ entries)

Rapid successive modifications

## Documentation Verification

NEWS.md includes feature description

README.md includes usage example

dev_scripts/README.md provides testing instructions

IMPLEMENTATION_SUMMARY.md explains technical details

All functions have proper roxygen2 documentation

## Code Quality

No R CMD check warnings or errors

Code follows existing style conventions

No hardcoded values (all configurable)

Proper error handling throughout

Informative console messages

Helpful user notifications

## Known Limitations

Document any known limitations or issues:

1.  Check interval is hardcoded to 5 seconds (could be made
    configurable)
2.  No support for removing entries (only adding)
3.  File must maintain same column structure

## Sign-off

Once all tests pass and the feature is verified:

All automated tests pass

All manual tests pass

Performance is acceptable

Documentation is complete

Code review completed

Ready for production use

Tested by: \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ Date:
\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ Version:
\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
