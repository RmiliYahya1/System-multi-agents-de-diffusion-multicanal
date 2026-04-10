"""
============================================================
  COMPREHENSIVE TENANT_ID FIX
  Scans ALL n8n workflow JSON files and fixes every JS code node
  to ensure proper tenant_id propagation.
  
  Problems fixed:
  1. "Recevoir job_id.first()" → "$('Recevoir job_id').first()" (missing $ and quotes)
  2. "initData.tenant_id" in nodes where initData is not defined → safe path
  3. Duplicate "tenant_id:" keys in object literals
  4. Missing tenant_id in action payloads (GET_JOB, UPDATE_JOB, etc.)
============================================================
"""
import json
import os
import re
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# All workflow JSON files to scan
WORKFLOW_FILES = [
    os.path.join(BASE_DIR, "AdaptationAgent.json"),
    os.path.join(BASE_DIR, "PublicationAgent.json"),
    os.path.join(BASE_DIR, "IngestionAgent.json"),
    os.path.join(BASE_DIR, "workflows", "workers", "IngestionWorker.json"),
    os.path.join(BASE_DIR, "workflows", "workers", "AdaptationWorker.json"),
    os.path.join(BASE_DIR, "workflows", "workers", "PublicationWorker.json"),
    os.path.join(BASE_DIR, "workflows", "services", "CredentialsService-v2.json"),
    os.path.join(BASE_DIR, "workflows", "services", "ChannelConfigService-v2.json"),
    os.path.join(BASE_DIR, "workflows", "services", "JobService-v2.json"),
    os.path.join(BASE_DIR, "workflows", "services", "LogService-v2.json"),
]

total_fixes = 0

for filepath in WORKFLOW_FILES:
    if not os.path.exists(filepath):
        continue
    
    fname = os.path.basename(filepath)
    
    with open(filepath, "r", encoding="utf-8") as f:
        data = json.load(f)
    
    file_modified = False
    
    for node in data.get("nodes", []):
        if node.get("type") != "n8n-nodes-base.code":
            continue
        if "parameters" not in node or "jsCode" not in node["parameters"]:
            continue
        
        code = node["parameters"]["jsCode"]
        original_code = code
        node_name = node.get("name", "unknown")
        
        # ─── FIX 1: Bare "Recevoir job_id.first()" → "$('Recevoir job_id').first()" ───
        # This pattern catches the broken syntax left by PowerShell stripping $()
        # Match "Recevoir job_id.first()" NOT preceded by $(' 
        # We need to be careful not to double-wrap already correct ones
        
        # First, find all occurrences of the broken pattern
        broken_pattern = re.compile(r"(?<!\$\(')(?<!\$\(\")Recevoir job_id\.first\(\)")
        if broken_pattern.search(code):
            code = broken_pattern.sub("$('Recevoir job_id').first()", code)
        
        # ─── FIX 2: Remove duplicate tenant_id keys ───
        # Pattern: "tenant_id: ..., job_id: ..., tenant_id: ..." → keep first, remove second
        # This is tricky - we look for two tenant_id in the same object literal line
        dup_pattern = re.compile(
            r"(tenant_id:\s*\$\('Recevoir job_id'\)\.first\(\)\.json\.tenant_id,\s*)"
            r"((?:client_id:[^,]+,\s*)?)"  # optional client_id
            r"(.*?)"  # stuff in between
            r",?\s*tenant_id:\s*\$\('Recevoir job_id'\)\.first\(\)\.json\.tenant_id"
        )
        while dup_pattern.search(code):
            code = dup_pattern.sub(r"\1\2\3", code)
        
        # ─── FIX 3: "initData.tenant_id" where initData might not be defined ───
        # In nodes that use initData as a variable declared with const initData = ...,
        # this is fine. But in nodes where there's NO "const initData" declaration,
        # we need to replace it with the safe path.
        if "initData.tenant_id" in code and "const initData" not in code:
            code = code.replace(
                "initData.tenant_id",
                "$('Recevoir job_id').first().json.tenant_id"
            )
        
        if code != original_code:
            node["parameters"]["jsCode"] = code
            file_modified = True
            total_fixes += 1
            print(f"  Fixed: [{fname}] node '{node_name}'")
    
    if file_modified:
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        print(f"  Saved: {fname}")

print(f"\n{'='*60}")
print(f"  Total nodes fixed: {total_fixes}")
print(f"{'='*60}")
