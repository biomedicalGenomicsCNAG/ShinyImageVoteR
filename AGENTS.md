# AGENTS.md

This file guides OpenAI's Codex on project structure and coding conventions

## Project Structure

- `/R/`:

  - `/modules/`: Shiny modules for different functionalities

    - `about_module.R`: About the developer of the app
    - `leaderboard_module.R`: Comparison of voting progress of all the involved institutes
    - `login_module.R`: Login functionality module
    - `user_stats_module.R`: Statistics of the user's voting behavior

  - `app.R`: main Shiny app entry
  - `global.R`: shared data loading code
  - `ui.R`: main UI layout that imports all modules
  - `server/*.R`: server logic modules

  - `/www/`: static resources (JS, CSS)
    - `css/`: custom styles for the app
    - `scripts/`: custom JavaScript for the app

---

## Coding Conventions

- Use Shiny modules consistently: each in UI (`mod_x_ui`) + server (`mod_x_server`)
- Modules files named `mod_*_ui.R` and `mod_*_server.R`
- Indent code with 2 spaces

---
