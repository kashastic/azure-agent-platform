{{- define "eurag.labels" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: agent-platform
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{- define "eurag.apiSelector" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/component: api
{{- end }}

{{- define "eurag.qdrantSelector" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/component: qdrant
{{- end }}

{{- define "eurag.webSelector" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/component: web
{{- end }}

{{- define "eurag.postgresSelector" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/component: postgres
{{- end }}

{{- define "eurag.redisSelector" -}}
app.kubernetes.io/name: eurag
app.kubernetes.io/component: redis
{{- end }}

{{/* Non-empty when the Turnstile bot check is fully configured. */}}
{{- define "eurag.turnstile" -}}
{{- if and .Values.public.turnstile.keyVaultSecret .Values.public.turnstile.sitekey -}}true{{- end -}}
{{- end }}

{{/* Key Vault secrets in use: the base list, plus the public ones. */}}
{{- define "eurag.secrets" -}}
{{- $secrets := .Values.azure.secrets -}}
{{- if .Values.public.hostname -}}
{{- $secrets = concat $secrets .Values.azure.publicSecrets -}}
{{- if include "eurag.turnstile" . -}}
{{- $secrets = concat $secrets (list (dict "keyVaultSecret" .Values.public.turnstile.keyVaultSecret "envName" "EURAG_TURNSTILE_SECRET")) -}}
{{- end -}}
{{- end -}}
{{- toYaml $secrets -}}
{{- end }}

{{- define "eurag.image" -}}
{{ required "image.repository is required" .Values.image.repository }}:{{ required "image.tag is required" .Values.image.tag }}
{{- end }}

{{/* Environment shared by the seed job and the API. */}}
{{- define "eurag.env" -}}
- name: QDRANT_URL
  value: "http://eurag-qdrant:6333"
- name: EURAG_DATA_DIR
  value: /app/var
# Model caches on the persistent volume, so ONNX models are downloaded once.
- name: HF_HOME
  value: /app/var/cache/hf
- name: FASTEMBED_CACHE_PATH
  value: /app/var/cache/fastembed
- name: EURAG_STRICT_BOOT
  value: {{ .Values.eurag.strictBoot | quote }}
- name: EURAG_RERANK_BATCH
  value: {{ .Values.eurag.rerankBatch | quote }}
{{- range (include "eurag.secrets" . | fromYamlArray) }}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: eurag-secrets
      key: {{ .envName }}
      optional: true
{{- end }}
{{- if .Values.public.hostname }}
# As in EURAG's production compose. The passwords above must come first:
# $(VAR) only expands variables defined earlier in the list.
- name: EURAG_AUTH_ENABLED
  value: "true"
- name: EURAG_DATABASE_URL
  value: "postgresql://eurag:$(POSTGRES_PASSWORD)@eurag-postgres:5432/eurag"
- name: EURAG_REDIS_URL
  value: "redis://:$(REDIS_PASSWORD)@eurag-redis:6379/0"
# Only the gateway can reach the API (network policy), and it replaces any
# client-sent X-Forwarded-For with the real peer address.
- name: EURAG_TRUST_PROXY
  value: "true"
- name: EURAG_FREE_ANON_QUESTIONS
  value: {{ .Values.public.freeAnonQuestions | quote }}
- name: EURAG_FREE_USER_QUESTIONS
  value: {{ .Values.public.freeUserQuestions | quote }}
{{- if include "eurag.turnstile" . }}
- name: EURAG_TURNSTILE_SITEKEY
  value: {{ .Values.public.turnstile.sitekey | quote }}
{{- end }}
{{- end }}
{{- range $name, $value := .Values.eurag.extraEnv }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{- define "eurag.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
capabilities:
  drop:
    - ALL
{{- end }}
