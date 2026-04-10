import json
import os

for filename in ['AdaptationAgent.json', 'PublicationAgent.json']:
    if os.path.exists(filename):
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        modified = False
        
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.code' and 'parameters' in node and 'jsCode' in node['parameters']:
                code = node['parameters']['jsCode']
                
                # The previous script produced: tenant_id: Recevoir job_id.first().json.tenant_id
                # We need to fix it to: tenant_id: $('Recevoir job_id').first().json.tenant_id
                new_code = code.replace("tenant_id: Recevoir job_id.first().json.tenant_id", "tenant_id: $('Recevoir job_id').first().json.tenant_id")
                new_code = new_code.replace("client_id: Recevoir job_id.first().json.client_id", "client_id: $('Recevoir job_id').first().json.client_id")
                
                if new_code != code:
                    node['parameters']['jsCode'] = new_code
                    modified = True
                    print('Fixed syntax error in', node['name'], 'in', filename)

        if modified:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
