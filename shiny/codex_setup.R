install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/source/linux-gnu/x86_64")
library(pak)
pak("renv")

sys_release <- system("lsb_release -c -s", intern = TRUE)
options(repos = c(CRAN = paste0("https://packagemanager.posit.co/cran/__linux__/", sys_release, "/latest")))
source("renv/activate.R")