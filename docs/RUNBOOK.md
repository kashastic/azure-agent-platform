# Runbook

From an empty Azure subscription to EURAG running on AKS, then back down. Run everything from the repo root on a Mac or Linux machine.

## 0. Prerequisites

```bash
brew install hashicorp/tap/terraform azure-cli Azure/kubelogin/kubelogin kubectl helm gh
terraform -version     # 1.9 or newer

az login
az account show -o table
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Optional: budget and alert emails. Kept out of Git on purpose.
export TF_VAR_alert_email="you@example.com"
```

Register the resource providers once (the Terraform providers are configured not to do this on every run):

```bash
for ns in Microsoft.ContainerService Microsoft.ContainerRegistry Microsoft.KeyVault \
          Microsoft.OperationalInsights Microsoft.Insights Microsoft.ManagedIdentity \
          Microsoft.Network Microsoft.Storage Microsoft.Compute Microsoft.Consumption \
          Microsoft.AlertsManagement Microsoft.PolicyInsights; do
  az provider register --namespace "$ns"
done
```

Student and trial subscriptions often restrict regions and VM sizes. Check before you start, and change `location` in `infra/envs/dev/common.tfvars` or `node_vm_size` in the AKS stack if needed:

```bash
az policy assignment list --query "[].{name:displayName, params:parameters}" -o json
az vm list-usage --location germanywestcentral -o table | grep -iE "total regional|standard bs"
az vm list-skus --location germanywestcentral --size Standard_D2s_v7 --query "[].restrictions" -o json
```

The globally unique names (Key Vault, registry, storage account) use `suffix` from `common.tfvars`. Change it if a name is taken.

## 1. Bootstrap (once)

Creates the state storage account and the three GitHub identities. Its own state is local.

```bash
cd infra/bootstrap
terraform init
terraform apply -var-file=../envs/dev/common.tfvars
cd ../..
```

This writes `infra/envs/dev/backend.hcl`. Commit it (it holds names, not secrets). Keep a copy of the bootstrap state next to the others, so it survives a lost laptop or an ephemeral Cloud Shell:

```bash
az storage blob upload --auth-mode login --account-name "$(terraform -chdir=infra/bootstrap output -raw state_storage_account)" \
  -c tfstate -n bootstrap/terraform.tfstate -f infra/bootstrap/terraform.tfstate --overwrite
```

Then configure GitHub Actions with the printed commands:

```bash
terraform -chdir=infra/bootstrap output -raw github_variables | sh
gh variable set PLATFORM_ADMIN_OBJECT_IDS --body "[\"$(az ad signed-in-user show --query id -o tsv)\"]"
gh secret set ALERT_EMAIL --body "$TF_VAR_alert_email"
```

In GitHub, create the `dev` environment (Settings, Environments) and add yourself as a required reviewer. The apply job waits for that approval.

Wait about two minutes before the next step: the new data-plane role on the state account takes a moment to propagate.

## 2. Foundation

```bash
make plan STACK=foundation      # read the plan
make apply STACK=foundation
gh variable set ACR_NAME --body "$(terraform -chdir=infra/envs/dev/foundation output -raw acr_name)"
```

Put the Anthropic API key into Key Vault. It never touches Git or Terraform state:

```bash
KV=$(terraform -chdir=infra/envs/dev/foundation output -raw key_vault_name)
read -rs ANTHROPIC_API_KEY
az keyvault secret set --vault-name "$KV" --name anthropic-api-key --value "$ANTHROPIC_API_KEY" -o none
unset ANTHROPIC_API_KEY
```

## 3. Build the EURAG image

```bash
gh workflow run build-eurag.yml -f eurag_ref=main
gh run watch
git pull      # the workflow committed the image tag to values-dev.yaml
```

## 4. Access

```bash
make plan apply STACK=access
```

To give a person access, add their user principal name to a team's `members` in `platform/teams.yaml` and apply again.

## 5. AKS (about 10 minutes)

```bash
make plan STACK=aks
make apply STACK=aks
make kubeconfig
kubectl get nodes      # opens a browser sign-in the first time
```

## 6. Platform: Argo CD and EURAG

```bash
make plan apply STACK=platform
kubectl -n argocd get applications
kubectl -n eurag get pods -w
```

The first start takes a while: the `seed-corpus` init container scrapes the EU sources and embeds them (watch it with `kubectl -n eurag logs deploy/eurag -c seed-corpus -f`), then the API loads its models. The scrape cache is kept on the volume, so later starts only ingest what is cached and skip unchanged documents.

### Loading the EUR-Lex cache by hand

EUR-Lex refuses requests from Azure datacenter IPs. In the cluster the seed logs `SKIPPED ... text does not match expected phrases` for the legal acts and only the portal sources get in (18 of 47 documents). Scrape on a laptop and copy the cache onto the volume:

```bash
# On the laptop, in the eu-rag checkout
python -m data.seed --scrape
tar czf eurag-raw.tgz -C data raw

# Against the cluster
POD=$(kubectl -n eurag get pods -l app.kubernetes.io/component=api -o name | cut -d/ -f2)
kubectl -n eurag cp eurag-raw.tgz $POD:/app/var/eurag-raw.tgz -c api
kubectl -n eurag exec $POD -c api -- sh -c 'mkdir -p /app/var/corpus-cache && tar xzf /app/var/eurag-raw.tgz -C /app/var/corpus-cache --strip-components=1 && rm /app/var/eurag-raw.tgz'
kubectl -n eurag delete pod $POD      # the init container ingests the cache on the next start
```

Don't run `python -m data.seed` with `kubectl exec` in the api container: it shares the API's memory limit and the container gets OOM-killed.

```bash
kubectl -n eurag port-forward svc/eurag 8000:8000
curl -s localhost:8000/healthz      # documents, embedder, llm
open http://localhost:8000
```

Argo CD UI:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
kubectl -n argocd port-forward svc/argocd-server 8080:80      # http://localhost:8080, user admin
```

## 7. Teardown

```bash
make down      # destroys platform, then aks
```

The foundation and access stacks stay up between sessions. To remove everything:

```bash
make destroy STACK=access
make destroy STACK=foundation
cd infra/bootstrap && terraform destroy -var-file=../envs/dev/common.tfvars
```

## Troubleshooting

| Symptom | Likely cause and fix |
| --- | --- |
| `RequestDisallowedByAzure` or `RequestDisallowedByPolicy` | The subscription only allows some regions. Change `location` in `common.tfvars` |
| `OperationNotAllowed` ... quota, or "VM size ... is not allowed in your subscription" | The error lists the sizes the subscription allows. Set `node_vm_size` in the AKS stack to one of them (Azure for Students: the v7 D-series) |
| `403` on `terraform init` | The Storage Blob Data role from bootstrap hasn't propagated yet. Wait and retry |
| `MissingSubscriptionRegistration` | A resource provider isn't registered. Register it (step 0) |
| `kubelogin: command not found` | `brew install Azure/kubelogin/kubelogin` |
| Pod stuck in `ContainerCreating`, event mentions `SecretProviderClass` | The `anthropic-api-key` secret is missing from Key Vault, or the federated credential is from an old cluster: re-apply the aks stack |
| `ImagePullBackOff` | The tag in `values-dev.yaml` was never built. Run the build workflow |
| `seed-corpus` restarts | Read its log. Scraping retries on the next start; raise memory in `seed.resources` if it was OOMKilled |
| `/healthz` shows 18 documents, seed log full of `SKIPPED` | EUR-Lex blocks cloud IPs. Load the cache by hand (section 6) |
| Pod `Pending` with `Insufficient cpu` | The AKS add-ons reserve most of a 2-vCPU node. Lower CPU requests or use a larger `node_vm_size` |
