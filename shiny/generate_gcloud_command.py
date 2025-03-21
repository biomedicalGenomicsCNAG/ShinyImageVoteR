import base64

# Path to your JSON file
json_file_path = "gsheets_config.json"

# Read the JSON from the file and load it into a Python dictionary
with open(json_file_path, "r") as f:
    json_data = f.read()

encoded_json = base64.b64encode(json_data.encode("utf-8")).decode("utf-8")

# Define your service name and image URL
service_name = "b1mg-variant-voting"
image_url = ""

# Construct the gcloud command
command = (
    f"gcloud run deploy {service_name} "
    f"--image {image_url} "
    f"--update-env-vars SERVICE_ACCOUNT_JSON={encoded_json}"
)

print("Run the following command:")
print(command)
