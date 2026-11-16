# Security

How the public EURAG deployment is protected, and why it looks the way it does.

## What happened before

EURAG first ran publicly on a single Google Cloud VM with Docker Compose. On 24 September 2026 Google suspended the project for cryptocurrency mining. The most likely way in was the web app: it was on Next.js 15.1.6 with React 19.0.0, inside the range of React2Shell (CVE-2025-55182), an unauthenticated remote code execution flaw in React Server Components that had been exploited since December 2025 to install miners. The lockfile had pinned that version since before the deploy, and nothing checked it.

Three things made it worse than it had to be:

1. **Nothing checked dependencies.** No scan in CI, no update bot.
2. **Nothing contained a compromised container.** All services shared one Docker network, so the web container could reach Redis and Qdrant, which had no passwords, and had unrestricted outbound internet to download a miner and reach a pool.
3. **Nothing noticed.** The first signal was Google's suspension email.

Every secret that was on that VM was treated as leaked and replaced. The fix for the web app is in [eu-rag#1](https://github.com/kashastic/eu-rag/pull/1).

## Layers on AKS

### 1. Keep known vulnerabilities out

- Next.js 15.5.29 and React 19.3.1 (patched), with npm `overrides` for three transitive packages Next.js pins to vulnerable versions.
- EURAG's CI runs `npm audit --omit=dev` as a failing step; Dependabot opens weekly updates for npm, pip, Docker and Actions.
- The images apply OS security updates at build time and carry no package tooling at runtime (no setuptools in the API image; no npm, yarn or corepack in the web image).
- `build-eurag` scans both images with Trivy and **only commits the new tag if neither has a fixable critical or high vulnerability**. A failing image sits in the registry but never reaches the cluster. On its first run the gate stopped the API image (zlib in the Debian base, a package vendored inside setuptools).

### 2. Expose as little as possible

- One public address: a static IP on the Envoy Gateway's load balancer, ports 80 and 443 only. Port 80 only redirects to HTTPS and answers Let's Encrypt challenges.
- No public IPs or SSH on nodes. The databases have no external address.
- The Kubernetes API accepts Entra ID sign-ins only; local accounts are disabled.

### 3. Contain a compromised pod

In the `eurag` namespace every pod starts from a default-deny network policy in both directions, then gets only what it needs:

| Pod | May receive from | May send to |
| --- | --- | --- |
| web (Next.js) | the gateway | DNS only. No internet, so a miner can't download a payload or reach a pool |
| api | the gateway | Qdrant, Postgres, Redis, DNS, and HTTPS on public addresses (Anthropic, Entra ID, blob storage, Turnstile). Private ranges and the cloud metadata endpoint are excluded |
| postgres, redis | the api | nothing |
| qdrant | the api | nothing |

The namespace enforces Pod Security `restricted`: non-root, no privilege escalation, all capabilities dropped, RuntimeDefault seccomp. The api, web, Postgres and Redis containers have read-only root filesystems; Qdrant writes an init marker next to its binary, so its root filesystem stays writable. No pod mounts a Kubernetes service account token.

### 4. Secrets

- The foundation stack generates EURAG's JWT secret, encryption key and the Postgres and Redis passwords straight into Key Vault. Nobody types or sees them; they live in Terraform state, in a storage account that only accepts Entra ID sign-ins.
- The Anthropic key and the Turnstile pair are added to Key Vault by hand.
- Pods read secrets through the Key Vault CSI driver with workload identity. Postgres and Redis each get a Kubernetes Secret with only their own password. The web app gets nothing.
- Nothing secret is in Git, in env files or in CI.

### 5. Abuse and cost

- Cloudflare Turnstile on anonymous questions and registration.
- 2 free anonymous questions per IP per day, then sign-up; 10 lifetime questions per free account, then the user's own key.
- Rate limits in Redis, shared by all API replicas.
- The API trusts `X-Forwarded-For` only because the gateway is the only thing that can reach it (network policy), and the gateway drops whatever the client sent before adding the real peer address. The load balancer keeps the client's source address (`externalTrafficPolicy: Local`).
- A monthly spend limit on the Anthropic key, a subscription budget alert, and a node CPU alert. A miner shows up as pegged CPU.

## What this does not cover

- **No web application firewall.** Envoy Gateway terminates TLS and routes; it does not inspect requests.
- **No runtime threat detection.** Microsoft Defender for Containers would flag crypto mining and similar behaviour directly; it is billed per vCore and not enabled in this lab.
- **Qdrant has no API key.** EURAG's client doesn't send one, so the network policy is Qdrant's only guard.
- **Accounts don't survive `make down`.** Postgres lives on a disk in the cluster, which is deleted with it. Fine for a demo environment, not for real users.
