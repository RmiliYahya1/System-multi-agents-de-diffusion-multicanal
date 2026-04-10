import json
import os
import re

for filename in ['AdaptationAgent.json', 'PublicationAgent.json']:
    if os.path.exists(filename):
        with open(filename, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        modified = False
        pattern = re.compile(r"return\s*\[\s*\{\s*json\s*:\s*\{")
        
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.code' and 'parameters' in node and 'jsCode' in node['parameters']:
                code = node['parameters']['jsCode']
                
                # Check if it doesn't already have tenant_id
                if 'tenant_id' not in code:
                    # Inject tenant_id at the start of the returned json object
                    new_code = pattern.sub("return [{ json: { tenant_id: Recevoir job_id.first().json.tenant_id, client_id: Recevoir job_id.first().json.client_id, ", code)
                    
                    if new_code != code:
                        node['parameters']['jsCode'] = new_code
                        modified = True
                        print('Aggressively patched', node['name'], 'in', filename)

        if modified:
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
