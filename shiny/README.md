
# Shiny App
	
## Quickstart

```bash
R -e "renv::restore()"
Rscript run.R
```

# Note for gcloud users
RAM has to be > 256MB

## Testing Image Serving

To test the recent changes for serving images from the local filesystem:

1.  **Ensure the Shiny application has access to the image path.** The application is configured to load images from a path specified in the `choosePic()$path` variable, expected to be an absolute path like `/vol/b1mg/screenshot_URO_003_mutations_varSorted_redoBAQ`.
2.  **Place a test image:** Create or copy a sample JPEG image to the exact path that will be returned by `choosePic()$path` in your testing environment. For example, if `choosePic()$path` returns `/vol/b1mg/test_image.jpg`, place your test image there.
3.  **Run the Shiny application.**
4.  **Navigate to the voting page.**
5.  **Verify that the image is displayed correctly.** The image should be loaded from the local filesystem via the server, not from an external URL.
6.  **Check server logs (if possible)** for any errors related to file access or image rendering.