"""
Fix duplicate keys (tenant_id, job_id) in Worker JSON files
"""
import json
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

WORKER_FILES = [
    os.path.join(BASE_DIR, "workflows", "workers", "AdaptationWorker.json"),
    os.path.join(BASE_DIR, "workflows", "workers", "PublicationWorker.json"),
]

for filepath in WORKER_FILES:
    if not os.path.exists(filepath):
        continue
    fname = os.path.basename(filepath)
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    modified = False
    for node in data.get("nodes", []):
        if node.get("type") != "n8n-nodes-base.code":
            continue
        if "parameters" not in node or "jsCode" not in node["parameters"]:
            continue
        
        code = node["parameters"]["jsCode"]
        original = code
        
        # Fix duplicate "tenant_id: input.tenant_id,\n    tenant_id: input.tenant_id,"
        code = code.replace(
            "tenant_id: input.tenant_id,\n    tenant_id: input.tenant_id,",
            "tenant_id: input.tenant_id,"
        )
        # Fix duplicate "job_id: input.job_id," appearing twice  
        # Replace the pattern where job_id appears duplicated
        code = code.replace(
            "_queue_tenant_id: input.tenant_id,\n    job_id: input.job_id,\n    _queue_attempt",
            "_queue_tenant_id: input.tenant_id,\n    _queue_attempt"
        )
        
        if code != original:
            node["parameters"]["jsCode"] = code
            modified = True
            print(f"  Fixed duplicates in: [{fname}] node '{node['name']}'")
    
    if modified:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  Saved: {fname}")

print("\nDone.")
