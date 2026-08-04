{{/*
Expand the name of the chart.
*/}}
{{- define "rocketmq-dashboard.name" -}}
{{- default "dashboard" .Values.dashboard.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "rocketmq-dashboard.fullname" -}}
{{- if .Values.dashboard.fullnameOverride }}
{{- .Values.dashboard.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "dashboard" .Values.dashboard.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rocketmq-dashboard.labels" -}}
{{ include "rocketmq-dashboard.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rocketmq-dashboard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rocketmq-dashboard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
dashboard configmap fullname
*/}}
{{- define "rocketmq-dashboard.configmap.fullname" -}}
{{ include "rocketmq-dashboard.fullname" . }}-cm
{{- end }}

{{/*
dashboard data path
*/}}
{{- define "rocketmq-dashboard.dataPath" -}}
/tmp/rocketmq-console/data
{{- end }}
