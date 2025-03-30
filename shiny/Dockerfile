# Use the official rocker/shiny image as the base image
FROM rocker/shiny:latest

ENV RENV_CONFIG_PAK_ENABLED=TRUE
ENV PPM_URL=packagemanager.posit.co/cran/__linux__/noble/latest

# Install system dependencies required by some R packages
RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libxml2-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /srv/shiny-server
RUN Rscript -e "options(repos = c(PPM = 'https://${PPM_URL}'));install.packages(c('pak','renv'))"
COPY renv.lock .
RUN Rscript -e "renv::init(bare=TRUE);options(renv.config.ppm.url = 'https://${PPM_URL}');renv::restore()"

# Copy your application files to the Shiny server directory
COPY config.R .
COPY app.R .

# Expose the Shiny server port
# EXPOSE 8000
EXPOSE 8080

# Run the Shiny server
# CMD ["R", "-e", "shiny::runApp(host='0.0.0.0', port=8000, launch.browser=FALSE)"]
CMD ["R", "-e", "shiny::runApp(host='0.0.0.0', port=8080, launch.browser=FALSE)"]
