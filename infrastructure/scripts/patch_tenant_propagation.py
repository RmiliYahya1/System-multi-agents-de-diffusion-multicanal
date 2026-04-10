import json
import os

def patch_file(filepath, replacements):
    print(f"Applying patches to {filepath}...")
    if not os.path.exists(filepath):
        print(f"Skipped {filepath} - File not found")
        return
        
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    modified = False
    for n in data.get('nodes', []):
        if 'code' in n.get('type', '').lower() or 'function' in n.get('type', '').lower():
            code = n.get('parameters', {}).get('jsCode', '')
            if not code:
                continue
                
            for old_str, new_str in replacements:
                if old_str in code:
                    code = code.replace(old_str, new_str)
                    n['parameters']['jsCode'] = code
                    modified = True
                    print(f"  - Node '{n['name']}': Replaced '{old_str[:30].strip()}...'")
            
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Saved {filepath}")
    else:
        print(f"No changes made to {filepath}")

# ----- 1. IngestionAgent.json -----
ingestion_agent_reps = [
    (
        "request_id: item.request_id,\n        status: 'DUPLICATE_IGNORED',",
        "tenant_id: item.tenant_id,\n        request_id: item.request_id,\n        status: 'DUPLICATE_IGNORED',"
    ),
    (
        "request_id: item.strategic?.request_id || `ITEM-${_item_index}`,\n        status: 'REJECTED_SCHEMA',",
        "tenant_id: item.tenant_id,\n        request_id: item.strategic?.request_id || `ITEM-${_item_index}`,\n        status: 'REJECTED_SCHEMA',"
    ),
    (
        "request_id: item.request_id,\n        status: 'REJECTED_BUSINESS',",
        "tenant_id: item.tenant_id,\n        request_id: item.request_id,\n        status: 'REJECTED_BUSINESS',"
    ),
    (
        "request_id: item.request_id,\n      status: item.status || 'JOB_CREATED',",
        "tenant_id: item.tenant_id,\n      request_id: item.request_id,\n      status: item.status || 'JOB_CREATED',"
    )
]

# ----- 2. IngestionWorker.json -----
ingestion_worker_reps = [
    (
        "job_id: job.job_id,\n      correlation_id: data.correlation_id,\n      action: 'ADAPT_CONTENT',",
        "tenant_id: job.tenant_id,\n      job_id: job.job_id,\n      correlation_id: data.correlation_id,\n      action: 'ADAPT_CONTENT',"
    )
]

# ----- 3. AdaptationWorker.json -----
adaptation_worker_reps = [
    (
        "job_id: input.job_id,\n    correlation_id: input.correlation_id || '',\n    action: 'ADAPT_CONTENT',",
        "tenant_id: input.tenant_id,\n    job_id: input.job_id,\n    correlation_id: input.correlation_id || '',\n    action: 'ADAPT_CONTENT',"
    ),
    (
        "job_id: job.job_id,\n      correlation_id: data.correlation_id,\n      action: 'PUBLISH_CONTENT',",
        "tenant_id: job.tenant_id,\n      job_id: job.job_id,\n      correlation_id: data.correlation_id,\n      action: 'PUBLISH_CONTENT',"
    )
]

# ----- 4. AdaptationAgent.json -----
adaptation_agent_reps = [
    (
        "json: {\n    job_id,\n    correlation_id,",
        "json: {\n    tenant_id: input.tenant_id,\n    job_id,\n    correlation_id,"
    ),
    (
        "job_id: data.job_id,\n    channel_name: data.channel_name,\n    result_status: 'ADAPTED',",
        "tenant_id: data.tenant_id,\n    job_id: data.job_id,\n    channel_name: data.channel_name,\n    result_status: 'ADAPTED',"
    ),
    (
        "job_id: data.job_id,\n    result_status: data._result_status,",
        "tenant_id: data.tenant_id,\n    job_id: data.job_id,\n    result_status: data._result_status,"
    )
]

# ----- 5. PublicationWorker.json -----
publication_worker_reps = [
    (
        "job_id: input.job_id,\n    correlation_id: input.correlation_id || '',\n    action: 'PUBLISH_CONTENT',",
        "tenant_id: input.tenant_id,\n    job_id: input.job_id,\n    correlation_id: input.correlation_id || '',\n    action: 'PUBLISH_CONTENT',"
    )
]

# ----- 6. PublicationAgent.json -----
publication_agent_reps = [
    (
        "json: {\n    job_id,\n    correlation_id,",
        "json: {\n    tenant_id: data.tenant_id,\n    job_id,\n    correlation_id,"
    )
]

if __name__ == "__main__":
    patch_file('IngestionAgent.json', ingestion_agent_reps)
    patch_file('workflows/workers/IngestionWorker.json', ingestion_worker_reps)
    patch_file('workflows/workers/AdaptationWorker.json', adaptation_worker_reps)
    patch_file('AdaptationAgent.json', adaptation_agent_reps)
    patch_file('workflows/workers/PublicationWorker.json', publication_worker_reps)
    patch_file('PublicationAgent.json', publication_agent_reps)

    print("\n[SUCCESS] Patching sequence complete.")
