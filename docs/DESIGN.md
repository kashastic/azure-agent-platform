# Design decisions

Each entry says what was chosen, why, and what it costs. The context throughout: a platform team that gives data and AI teams a safe, repeatable way to run workloads on Azure, where the data can be sensitive.

## Terraform layout

### 1. Five small stacks, each with its own state

`bootstrap`, `foundation`, `access`, `aks` and `platform` are separate root modules with separate state files in one storage container.

- **Why:** a change to one stack can't touch resources in another (small blast radius), plans stay fast, and the expensive AKS stack can be destroyed and rebuilt while the network, Key Vault and registry stay up.
- **Trade-off:** applying from zero means running stacks in order. The Makefile's `up` target and the runbook make the order explicit.

### 2. Remote state in Azure Storage, signed in with Entra ID

The backend uses `use_azuread_auth`, so access to state is a data-plane role assignment (Storage Blob Data Contributor or Reader), not the storage account key. Versioning and soft delete are on, so an earlier state version can be restored. Terraform takes a blob lease while it writes, so two applies can't run at once.

- **Why:** state can contain secrets and is the record of what exists, so it gets the same identity-based access as everything else.
- **Trade-off:** the bootstrap stack that creates this storage keeps its own state locally (chicken and egg). It can be migrated in with `terraform init -migrate-state`.

### 3. Stacks find each other by naming convention

Names follow `<type>-<project>-<env>[-suffix]` (for example `kv-agentplat-dev-ak7`), and stacks read each other's resources through data sources by name.

- **Why:** no hard-coded IDs, and no stack needs read access to another stack's state.
- **Trade-off:** renaming a resource means updating the convention in every stack that reads it. Publishing outputs through `terraform_remote_state` is the alternative; it couples stacks to each other's state instead.

### 4. Shared modules, environment-specific stacks

Modules (`network`, `key-vault`, `container-registry`, `log-analytics`, `aks`, `guardrails`) hold the reusable resource shapes. Stacks under `envs/dev` wire them together with environment values from one `common.tfvars`.

- **Why:** a `prod` environment is a new folder with different values, not a copy of resource code.

## Identity

### 5. Three GitHub identities with OIDC federation

GitHub Actions signs in to Azure with short-lived OIDC tokens. Each user-assigned managed identity trusts only one token subject:

| Identity | Trusted subject | Rights |
| --- | --- | --- |
| plan | pull requests (and manual runs on main) | Reader, read-only state |
| apply | the `dev` environment only | Contributor, RBAC Administrator, state writer |
| build | the main branch | AcrPush on the registry, nothing else |

- **Why:** nothing secret is stored in GitHub. A pull request, including a malicious one, can read but never change infrastructure. Applies need an approval on the environment, and the build job can push images but can't touch infrastructure.
- **Trade-off:** the apply identity is broad (subscription scope) for a lab. In a shared subscription it would be scoped to the platform resource groups, with an ABAC condition on the RBAC Administrator role that limits which roles it may hand out.

### 6. AKS with Entra ID, Azure RBAC, and local accounts disabled

People sign in to the cluster with Entra ID through `kubelogin`. Permissions are Azure role assignments (`Azure Kubernetes Service RBAC Reader/Writer/Admin/Cluster Admin`), scoped to the cluster or to one namespace. There is no static admin kubeconfig.

- **Why:** one identity system for Azure and Kubernetes, every permission auditable in the same place, and access disappears when someone leaves the group.
- **Trade-off:** tooling has to support Entra ID sign-in (kubelogin). Break-glass access is through the Cluster Admin role, not a local account.

### 7. Managed identities for the cluster

The control plane uses a user-assigned identity created before the cluster, with Network Contributor on the AKS subnet only. The kubelet identity gets AcrPull on the registry, so nodes pull images without registry credentials. A 60-second pause lets the subnet role propagate before the cluster is created.

### 8. Workload identity and the Key Vault CSI driver for EURAG

EURAG's pod runs as the `eurag` service account. A federated credential on EURAG's managed identity trusts tokens for exactly `system:serviceaccount:eurag:eurag` from this cluster's OIDC issuer. The Secrets Store CSI driver uses that identity to read `anthropic-api-key` from Key Vault and mirror it into a Kubernetes Secret.

- **Why:** there is no client secret or key anywhere, the identity can read secrets and nothing else (Key Vault Secrets User), and every read is in the Key Vault audit log.
- **Detail:** the managed identity lives in the foundation stack, so its client ID survives cluster rebuilds. Only the federated credential, which names the cluster's issuer, lives in the AKS stack.

## Kubernetes

### 9. Azure CNI Overlay with Cilium

Nodes take IPs from the VNet subnet; pods get IPs from a separate overlay range (`10.244.0.0/16`). Cilium (eBPF) enforces NetworkPolicies.

- **Why:** a `/22` subnet is enough for many pods, pod ranges never collide with the VNet or peered networks, and network policies are enforced without an extra add-on.
- **Detail:** `max_pods` is 50 instead of the overlay default of 250. AKS reserves kubelet memory per possible pod, so a lower limit leaves noticeably more memory for workloads on a small node.

### 10. GitOps with Argo CD; Terraform only bootstraps it

Terraform installs Argo CD with Helm and registers two Applications. From then on, Git is the source of truth: Argo CD syncs automatically, prunes removed resources, and reverts manual changes (self-heal).

The Applications come from a small local chart rather than `kubernetes_manifest`, so Terraform can plan before Argo CD's CRDs exist. Values that only Azure knows (registry, Key Vault name, tenant, workload identity client ID) are passed as Helm parameters by Terraform. Everything else, including the image tag, comes from Git.

- **Why:** each tool owns what it is good at. Terraform owns Azure resources and their IDs; Argo CD owns what runs in the cluster. CI never holds cluster credentials.
- **Trade-off:** two places define the EURAG deployment's inputs. The split is fixed: Azure-derived values from Terraform, everything else from Git.

### 11. One teams.yaml, two consumers

`platform/teams.yaml` is read by Terraform (`yamldecode`) for Entra ID groups, namespace-scoped Azure RBAC and Key Vault access, and by Argo CD as a Helm value file for namespaces, quotas, default limits and default-deny network policies.

- **Why:** onboarding is one reviewed pull request, the two systems can't disagree about a team, and the Git history is the access log.
- **Trade-off:** a change needs both the Terraform apply and the Argo CD sync to be complete. Group membership changes need only the access stack.

### 12. Packaging EURAG

- **Recreate, one replica.** EURAG's registry is a SQLite file on an Azure Disk (ReadWriteOnce). Two pods at once would fight over the disk and could serve different registries. The HPA template exists but is off until the registry moves to Postgres, which EURAG already does for auth and chat history.
- **Qdrant as a StatefulSet** with its own disk, reachable only from the EURAG API (NetworkPolicy).
- **Seed on first boot only.** An init container scrapes the official EU sources and embeds them into Qdrant. A registry on the volume marks a finished seed, so restarts skip it. The raw scrape cache is an `emptyDir`; it is only needed while seeding.
- **Probes sized to the app.** A startup probe allows up to six minutes for the ONNX models to load, so liveness can't kill a pod that is still starting.
- **Limits from measurement.** EURAG's own measurements: about 835 MB idle, 1.8 GB answering, around 2.1 GB on the escalation path with the reranker batch capped at 8. The memory limit is 2.5 GiB.
- **Hardening.** Non-root (UID 10001), no privilege escalation, all capabilities dropped, RuntimeDefault seccomp, no service account token. The namespace enforces the Pod Security `baseline` level and warns on `restricted`.
- **Not exposed publicly.** The service is ClusterIP and reached through `kubectl port-forward`, which requires an Entra ID sign-in. A public ingress with TLS and EURAG's own auth turned on is a deliberate next step.

## Guardrails and cost

### 13. Azure Policy with the deny effect

Each platform resource group gets the built-in *Allowed locations* policy (the configured region only) and *Require a tag on resources* for `owner`, `env` and `cost-center`.

- **Why:** a wrong region (data residency) or an untagged resource (unknown owner and cost) fails at deploy time instead of appearing in a compliance report later.

### 14. Budget at subscription scope, log ingestion capped

AKS bills node VMs and disks to its node resource group, so a resource-group budget on the platform groups would miss most of the cost. The budget is on the subscription. The Log Analytics workspace has a 0.5 GB daily cap.

### 15. Monitoring sized for cost

Container Insights uses the "logs and events" preset (container logs, Kubernetes events, pod inventory, every 5 minutes, `kube-system` excluded). Control plane logs include `kube-audit-admin` (changes, not reads) and `guard` (Entra ID sign-ins). Alerts cover node CPU and memory, and any workload container restart, which is how an out-of-memory kill would show up. EURAG's own devlog records exactly that failure on a 4 GB host.

## What the first deployment changed

The code was written first and then deployed from an empty subscription. These are the things that only showed up against real Azure, and what changed because of them.

- **GitHub's OIDC subject format.** The first image build failed to sign in with `AADSTS700213`. GitHub now names the repository in token subjects by immutable IDs (`repo:owner@id/repo@id:...`), not by name. The federated credentials in bootstrap now use that form, which also means renaming the repository or account can't hand these identities to someone else.
- **ACR Tasks unavailable.** `az acr build` is not permitted on student and free-credit subscriptions (`TasksOperationsNotAllowed`). Images are built in GitHub Actions with the push-only build identity, which was the intended path anyway.
- **VM sizes and quota.** Azure for Students limits the regions (five in Europe for this subscription) and marks most VM sizes as not available for the subscription, while the sizes it does allow had zero quota. A quota request came back `ResourceNotAvailableForOffer`. I found this by intersecting the Compute SKU API's restrictions with the per-family quotas, then moved the subscription to pay-as-you-go. The node size is a variable for exactly this reason.
- **Deprecated arguments.** `enable_rbac_authorization` on Key Vault and `resource_group_name` on federated credentials are deprecated in azurerm 4.x and were replaced, so the plan is warning-free.
- **Bootstrap state.** The bootstrap stack keeps local state by design. When running from an ephemeral shell, a copy goes into the state account (`bootstrap/terraform.tfstate`) right after apply.

