# Services Kubernetes — Conventions — Diffusion Platform

> **Scope** : tous les Services dans `infrastructure/kubernetes/`.
> **Étape** : 7/15 — Refonte et standardisation des Services.

---

## A. Type de Service par cas d'usage

| Type | Quand l'utiliser | Exemples dans le projet |
|---|---|---|
| `ClusterIP` (défaut) | Service interne, accessible seulement à l'intérieur du cluster | n8n-main, queue-service, prometheus, grafana, vault, kong-proxy, kong-admin |
| `Headless` (`clusterIP: None`) | StatefulSet nécessitant la résolution DNS pod-par-pod (ex: `postgres-0.postgres.data`) | postgres, redis |
| `NodePort` | **Dev local uniquement** (Docker Desktop, Minikube) — JAMAIS en staging/prod | n8n-main-nodeport, grafana-nodeport… *(overlay dev seulement)* |
| `LoadBalancer` | **À éviter** — préférer Ingress ALB (étape 8). Coûteux sur AWS (1 ELB par Service) | — |
| `ExternalName` | Alias DNS cross-namespace ou alias vers un nom DNS externe | postgres, redis (ns app), n8n-main (ns gateway), exporters (ns observability) |

### Règles absolues

- **NodePort en prod/staging → interdit**. La CI vérifie : `kubectl kustomize overlays/prod/ | grep "type: NodePort"` doit être vide.
- **LoadBalancer direct → interdit** en dehors de l'Ingress Controller. L'exposition publique passe uniquement par l'Ingress ALB (étape 8).
- **L'API admin Kong** (`kong-admin`, port 8001) ne doit JAMAIS être exposée via NodePort ou Ingress, **même en dev**.

---

## B. Convention de nommage des Services

| Pattern | Usage | Exemple |
|---|---|---|
| `<component>` | Service principal d'un workload | `postgres`, `redis`, `n8n-main`, `prometheus` |
| `<component>-proxy` | Trafic public/proxy d'un composant multi-port | `kong-proxy` |
| `<component>-admin` | API d'administration — interne uniquement | `kong-admin` |
| `<component>-headless` | Headless explicite (si le service principal n'est pas headless) | *(non utilisé ici)* |
| `<component>-nodeport` | Service NodePort dev-only (overlay uniquement) | `n8n-main-nodeport`, `grafana-nodeport` |
| `<component>-exporter` | ExternalName vers un exporter Prometheus cross-namespace | `postgres-exporter`, `redis-exporter` |

**Règles** :
- Tirets uniquement (pas d'underscores).
- Pas de suffixe `-svc` (redondant).
- Le nom dans le namespace `observability` pour les ExternalName reflète la fonction de scraping (`postgres-exporter`) et non le workload cible (`postgres`), pour distinguer clairement l'alias.

---

## C. Convention des ports

### Règles obligatoires

1. **Nommer tous les ports** — `name: http`, `name: postgres`, etc.
2. **`targetPort: <name>`** — utiliser le nom du containerPort, jamais un entier brut.
3. **`protocol: TCP`** — toujours explicite (évite les surprises avec UDP).
4. **`appProtocol:`** — renseigner quand applicable (aide les Service Mesh, AWS ALB, et le debugging).

### Tableau des `appProtocol` utilisés

| Valeur | Workloads concernés |
|---|---|
| `http` | n8n-main (5678), queue-service (3002), kong-proxy (80), kong-admin (8001), vault (8200), prometheus (9090), grafana (3000), exporters (9121, 9187) |
| `postgresql` | postgres (5432) |
| `redis` | redis (6379) |

---

## D. Convention des labels et selectors

### Selector (immutable après création)

```yaml
selector:
  app: <name>   # ex: app: kong
```

Le selector `app: <name>` est **immutable** une fois appliqué sur un cluster vivant. On ne le modifie jamais après création. Les Services `kong-proxy` et `kong-admin` partagent le même selector `app: kong` — c'est intentionnel.

### Labels standards (en plus du selector)

```yaml
metadata:
  labels:
    app.kubernetes.io/name: <name>
    app.kubernetes.io/component: <component>   # voir HARDENING_STANDARDS.md
    app.kubernetes.io/part-of: diffusion-platform
    app.kubernetes.io/managed-by: kustomize
```

---

## E. Annotations

### Annotations Prometheus (sur le pod template, pas sur le Service)

Les annotations `prometheus.io/*` sont portées par le **pod template** des Deployments/StatefulSets (ajoutées à l'étape 6) — Prometheus scrape les pods directement via les ExternalName Services.

### Annotations de documentation des ExternalName

```yaml
annotations:
  diffusion.platform/cross-namespace-alias: "true"
  diffusion.platform/target-namespace: "<env>-<layer>"
```

Ces annotations sont purement documentaires — elles n'ont aucun effet sur le routage.

### Annotations ALB (étape 8)

Les annotations `service.beta.kubernetes.io/aws-load-balancer-*` seront ajoutées **uniquement** sur les Services de type LoadBalancer dans l'overlay prod à l'étape 8. Elles ne doivent pas apparaître sur les Services ClusterIP.

---

## F. Sécurité — séparation public vs admin

### Principe

Tout port d'administration doit être dans un Service **séparé** du Service public. Cela permet :
- D'appliquer des NetworkPolicies distinctes (étape 9) : seul l'Ingress peut atteindre `kong-proxy`, seuls les outils internes peuvent atteindre `kong-admin`.
- D'auditer facilement l'exposition : un `grep "type: ClusterIP" | grep admin` révèle tous les Services admin.

### Application : Kong

| Service | Port | Accessible par | Jamais exposé via |
|---|---|---|---|
| `kong-proxy` | 80 | Ingress Controller, Ingress ALB | — |
| `kong-admin` | 8001 | Opérateurs internes (debug), NetworkPolicy | Ingress, NodePort |

### Règle dev

Même en dev local, `kong-admin` **n'a pas de NodePort**. Pour interagir avec l'API admin en dev, utiliser `kubectl port-forward` :

```bash
kubectl port-forward svc/dev-kong-admin 8001:8001 -n dev-gateway
```

---

## G. Services ExternalName : rôle et limitation

Les Services `ExternalName` agissent comme des alias CNAME. Ils permettent à un Pod dans le namespace `observability` de résoudre `postgres-exporter` → `postgres.data.svc.cluster.local` sans connaître le namespace exact.

**Limitations** :
- Un ExternalName ne filtre pas les ports — le Pod appelant décide du port.
- Les ports déclarés dans un ExternalName sont **documentaires uniquement** (pas de NAT/iptables).
- Les NetworkPolicies s'appliquent sur la destination réelle, pas sur l'alias.

**Mise à jour par overlay** : Les patches dans chaque overlay remplacent `externalName` par la valeur préfixée par l'environnement (ex: `postgres.dev-data.svc.cluster.local`).
