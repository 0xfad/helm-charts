{{/*
Expand the name of the chart.
*/}}
{{- define "affine.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "affine.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "affine.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "affine.labels" -}}
helm.sh/chart: {{ include "affine.chart" . }}
{{ include "affine.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "affine.selectorLabels" -}}
app.kubernetes.io/name: {{ include "affine.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "affine.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "affine.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the bundled PostgreSQL resources.
*/}}
{{- define "affine.postgresql.fullname" -}}
{{- printf "%s-postgresql" (include "affine.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the bundled Redis resources.
*/}}
{{- define "affine.redis.fullname" -}}
{{- printf "%s-redis" (include "affine.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the secret holding generated/derived credentials (DATABASE_URL, etc.).
*/}}
{{- define "affine.secretName" -}}
{{- printf "%s-env" (include "affine.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Effective database connection settings, resolved from either the bundled
PostgreSQL or externalDatabase. Usage: (include "affine.database.host" .)
*/}}
{{- define "affine.database.host" -}}
{{- if .Values.postgresql.enabled }}
{{- include "affine.postgresql.fullname" . }}
{{- else }}
{{- required "externalDatabase.host is required when postgresql.enabled is false" .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{- define "affine.database.port" -}}
{{- if .Values.postgresql.enabled }}5432{{ else }}{{ .Values.externalDatabase.port }}{{ end }}
{{- end }}

{{- define "affine.database.user" -}}
{{- if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.username }}{{ else }}{{ .Values.externalDatabase.username }}{{ end }}
{{- end }}

{{- define "affine.database.name" -}}
{{- if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.database }}{{ else }}{{ .Values.externalDatabase.database }}{{ end }}
{{- end }}

{{/*
Effective Redis host.
*/}}
{{- define "affine.redis.host" -}}
{{- if .Values.redis.enabled }}
{{- include "affine.redis.fullname" . }}
{{- else }}
{{- required "externalRedis.host is required when redis.enabled is false" .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{/*
Name of the secret holding the database password.
*/}}
{{- define "affine.database.passwordSecret" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.existingSecret | default (include "affine.secretName" .) }}
{{- else }}
{{- .Values.externalDatabase.existingSecret | default (include "affine.secretName" .) }}
{{- end }}
{{- end }}

{{/*
Key within the password secret that holds the database password.
*/}}
{{- define "affine.database.passwordSecretKey" -}}
{{- if and .Values.postgresql.enabled .Values.postgresql.auth.existingSecret }}
{{- "postgres-password" }}
{{- else if and (not .Values.postgresql.enabled) .Values.externalDatabase.existingSecret }}
{{- .Values.externalDatabase.existingSecretPasswordKey }}
{{- else }}
{{- "db-password" }}
{{- end }}
{{- end }}

{{/*
Whether the chart needs to create its own secret to hold the db password.
*/}}
{{- define "affine.createOwnSecret" -}}
{{- if .Values.postgresql.enabled }}
{{- if not .Values.postgresql.auth.existingSecret }}true{{ end }}
{{- else }}
{{- if not .Values.externalDatabase.existingSecret }}true{{ end }}
{{- end }}
{{- end }}

{{/*
The plaintext database password used when the chart manages its own secret.
*/}}
{{- define "affine.database.plainPassword" -}}
{{- if .Values.postgresql.enabled }}{{ .Values.postgresql.auth.password }}{{ else }}{{ .Values.externalDatabase.password }}{{ end }}
{{- end }}

{{/*
Name of the secret holding AFFINE_PRIVATE_KEY.
*/}}
{{- define "affine.privateKey.secretName" -}}
{{- .Values.affine.privateKey.existingSecret | default (include "affine.secretName" .) }}
{{- end }}

{{- define "affine.privateKey.secretKey" -}}
{{- .Values.affine.privateKey.existingSecretKey | default "private-key" }}
{{- end }}

{{/*
Resolve the private key value for use in the chart-managed Secret.
Uses `lookup` to reuse an existing value across helm upgrades so that
token signing keys survive chart upgrades without the user having to
manage the secret manually.
*/}}
{{- define "affine.privateKey.value" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (include "affine.secretName" .) -}}
{{- if and $existing (index $existing.data "private-key") -}}
{{- index $existing.data "private-key" | b64dec }}
{{- else -}}
{{- genPrivateKey "ed25519" }}
{{- end -}}
{{- end }}

{{/*
Shared environment for the AFFiNE server and the migration job.
DATABASE_URL relies on Kubernetes $(VAR) expansion of DB_PASSWORD, so the
plaintext password never has to be rendered into the manifest.
*/}}
{{- define "affine.env" -}}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.database.passwordSecret" . }}
      key: {{ include "affine.database.passwordSecretKey" . }}
- name: DATABASE_URL
  value: postgresql://{{ include "affine.database.user" . }}:$(DB_PASSWORD)@{{ include "affine.database.host" . }}:{{ include "affine.database.port" . }}/{{ include "affine.database.name" . }}
- name: REDIS_SERVER_HOST
  value: {{ include "affine.redis.host" . | quote }}
- name: REDIS_SERVER_PORT
  value: {{ (ternary "6379" (printf "%v" .Values.externalRedis.port) .Values.redis.enabled) | quote }}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.password }}
- name: REDIS_SERVER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.secretName" . }}
      key: redis-password
{{- end }}
{{- if and (not .Values.redis.enabled) .Values.externalRedis.database }}
- name: REDIS_SERVER_DATABASE
  value: {{ .Values.externalRedis.database | quote }}
{{- end }}
- name: AFFINE_INDEXER_ENABLED
  value: {{ .Values.affine.indexerEnabled | quote }}
- name: AFFINE_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "affine.privateKey.secretName" . }}
      key: {{ include "affine.privateKey.secretKey" . }}
{{- if .Values.affine.serverExternalUrl }}
- name: AFFINE_SERVER_EXTERNAL_URL
  value: {{ .Values.affine.serverExternalUrl | quote }}
- name: AFFINE_SERVER_HTTPS
  value: {{ hasPrefix "https://" .Values.affine.serverExternalUrl | quote }}
{{- end }}
{{- with .Values.affine.extraEnv }}
{{- toYaml . }}
{{- end }}
{{- end }}
