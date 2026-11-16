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
{{- range .Values.azure.secrets }}
- name: {{ .envName }}
  valueFrom:
    secretKeyRef:
      name: eurag-secrets
      key: {{ .envName }}
      optional: true
{{- end }}
{{- range $name, $value := .Values.eurag.extraEnv }}
- name: {{ $name }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}

{{- define "eurag.containerSecurityContext" -}}
allowPrivilegeEscalation: false
capabilities:
  drop:
    - ALL
{{- end }}
