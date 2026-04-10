import hmac, hashlib, base64, json, time

# Configuration Kong (depuis kong.yml)
SECRET = "Cl3_S3cr3t3_B1ind3e_2026_SUPER_SECRET_KEY!"
ISS = "emetteur_demo_01"  # key du consumer dans Kong

# Header
header = {"alg": "HS256", "typ": "JWT"}

# Payload
payload = {
    "iss": ISS,
    "tenant_id": "1",
    "exp": int(time.time()) + 3600,  # expire dans 1 heure
    "iat": int(time.time())
}

def b64url(data):
    return base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).rstrip(b'=').decode()

h = b64url(header)
p = b64url(payload)
signature = hmac.new(SECRET.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest()
sig = base64.urlsafe_b64encode(signature).rstrip(b'=').decode()

jwt_token = f"{h}.{p}.{sig}"

print("=" * 60)
print("JWT Token genere avec succes !")
print("=" * 60)
print()
print(jwt_token)
print()
print(f"Payload: {json.dumps(payload, indent=2)}")
print(f"Expire dans: 1 heure")
