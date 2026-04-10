import json

file_path = "c:/Users/yahya/Documents/system-de-diffusion/IngestionAgent.json"

with open(file_path, "r", encoding="utf-8") as f:
    text = f.read()

# Remplacement thread-safe du scope global vers node
text = text.replace("$getWorkflowStaticData('global')", "$getWorkflowStaticData('node')")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(text)

print(f"IngestionAgent updated successfully.")
