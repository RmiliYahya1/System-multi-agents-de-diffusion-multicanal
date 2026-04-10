import json
import os

for filename in ['AdaptationAgent.json', 'PublicationAgent.json']:
    if os.path.exists(filename):
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        modified = False
        for node in data.get('nodes', []):
            if node['type'] == 'n8n-nodes-base.code' and 'parameters' in node and 'jsCode' in node['parameters']:
                code = node['parameters']['jsCode']
                new_code = code
                if 'job_id: initData.job_id' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('job_id: initData.job_id', 'job_id: initData.job_id, tenant_id: initData.tenant_id')
                if 'job_id: inputData.job_id' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('job_id: inputData.job_id', 'job_id: inputData.job_id, tenant_id: inputData.tenant_id')
                if 'action: \"GET_JOB\"' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('action: \"GET_JOB\"', 'action: \"GET_JOB\", tenant_id: initData.tenant_id')
                if 'action: \'GET_JOB\'' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('action: \'GET_JOB\'', 'action: \'GET_JOB\', tenant_id: initData.tenant_id')
                if 'action: \"UPDATE_JOB\"' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('action: \"UPDATE_JOB\"', 'action: \"UPDATE_JOB\", tenant_id: initData.tenant_id')
                if 'action: \'UPDATE_JOB\'' in code and 'tenant_id' not in code:
                    new_code = new_code.replace('action: \'UPDATE_JOB\'', 'action: \'UPDATE_JOB\', tenant_id: initData.tenant_id')
                
                if new_code != code:
                    node['parameters']['jsCode'] = new_code
                    modified = True
                    print('Patched', node['name'], 'in', filename)

        if modified:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
