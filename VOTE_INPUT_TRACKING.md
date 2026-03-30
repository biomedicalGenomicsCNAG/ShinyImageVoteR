# Vote Input Method Tracking

## Overview
This document describes the implementation of vote input method tracking in ShinyImageVoteR. This feature tracks whether users cast votes using keyboard hotkeys or mouse clicks to help analyze the relationship between input method and voting speed.

## Motivation
Analysis revealed that median vote times range from 2-15 seconds across users. We want to understand how much of this difference is explained by hotkey usage versus mouse clicking.

## Implementation

### 1. JavaScript Changes (hotkeys.js)

#### Hotkey Detection
When a user presses a hotkey (1, 2, 3, 4 for radio buttons or a, s, d, f for checkboxes):
- The input element is marked with `dataset.inputMethod = "hotkey"`
- `Shiny.setInputValue("voting-last_input_method", "hotkey")` sends this information to R

#### Mouse Click Detection
When a user clicks on a radio button or checkbox:
- The click is verified to be within the voting questions div (same validation as hotkeys)
- The input element is marked with `dataset.inputMethod = "mouse"`
- `Shiny.setInputValue("voting-last_input_method", "mouse")` sends this information to R

**Note**: This validation prevents accidental tracking of clicks on other inputs with the same names elsewhere in the application.

### 2. R Server Changes

#### User Info Structure (main_server.R)
When a user logs in, their `user_info.json` file is initialized with:
```json
{
  "user_id": "User1",
  "voting_institute": "InstituteA",
  "images_randomisation_seed": 12345,
  "vote_input_methods": {
    "hotkey_count": 0,
    "mouse_count": 0,
    "unknown_count": 0
  }
}
```

**Note**: The `unknown_count` field tracks cases where the input method couldn't be determined, which helps identify potential issues with the tracking mechanism.

#### Vote Tracking (mod_voting.R)
When a user casts a **new vote** (not a vote change):
1. The input method is read from `input$last_input_method`
2. If not set, it's marked as "unknown" (with a warning logged)
3. The `user_info.json` file is read
4. The appropriate counter (`hotkey_count`, `mouse_count`, or `unknown_count`) is incremented
5. The updated info is written back to `user_info.json`

**Note**: 
- Vote changes are not tracked to avoid skewing the data. We only track initial votes.
- Using "unknown" instead of defaulting to "mouse" ensures accurate data and helps identify tracking issues.

## Data Analysis

After users complete their voting sessions, the `user_info.json` files can be analyzed to:
1. Calculate the percentage of hotkey vs mouse usage per user
2. Correlate this with average voting times (from `time_till_vote_casted_in_seconds` in annotations)
3. Determine if hotkey users are significantly faster

### Example Analysis Query
For each user:
- Read `user_info.json` to get hotkey/mouse counts
- Read `user_annotations.tsv` to get vote times
- Calculate:
  - Hotkey usage percentage: `hotkey_count / (hotkey_count + mouse_count) * 100`
  - Median vote time: median of `time_till_vote_casted_in_seconds`
- Plot correlation between hotkey usage and vote speed

## Files Modified

1. **inst/shiny-app/www/js/hotkeys.js**: Added input method detection and Shiny communication
2. **vignettes/www/hotkeys.js**: Updated to match inst version
3. **R/main_server.R**: Added `vote_input_methods` initialization to user_info
4. **R/mod_voting.R**: Added tracking logic to update user_info.json after each vote

## Testing

To test this implementation:
1. Start the Shiny app
2. Log in as a user
3. Vote using hotkeys (press 1, 2, 3, or 4)
4. Vote using mouse clicks
5. Check the `user_info.json` file for the user - it should show updated counts

Example:
```json
{
  "user_id": "TestUser",
  "voting_institute": "TestInstitute",
  "images_randomisation_seed": 67890,
  "vote_input_methods": {
    "hotkey_count": 12,
    "mouse_count": 5,
    "unknown_count": 0
  }
}
```

**Note**: If `unknown_count` is greater than 0, it indicates potential issues with the tracking mechanism that should be investigated.

## Future Enhancements

Potential improvements:
1. Track vote changes separately to understand behavior patterns
2. Add per-vote logs instead of just counts for more detailed analysis
3. Add real-time dashboard showing hotkey vs mouse usage statistics
4. Export aggregated statistics across all users
