{{- define "templating-deep-dive.fullname" -}}
{{- $defaultName := printf "%s-%s" .Release.Name .Chart.Name -}}
{{- .Values.customName | default $defaultName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "templating-deep-dive.selectorLabels" -}}
app: {{ .Chart.Name}}
release: {{ .Release.Name }}
managed-by: "helm"
{{- end -}}


{{/*Expects an integer or string to be passed as the context*/}}
{{- define "templating-deep-dive.validations.portRange" -}}
{{- $sanitizedPort := . | int -}}
{{/*Validate Port*/}}
{{- if or (lt $sanitizedPort 1) (gt $sanitizedPort 65535) -}}
{{- fail (dict "errorKey" "port" "errorMessage" "Port must be a positive integer between 0 and 65535" | toJson) -}}
{{- end -}}
{{- end -}}

{{/*Expects an object with port and type to be passed as $values*/}}
{{- define "templating-deep-dive.validations.service" -}}
{{- include "templating-deep-dive.validations.portRange" .port -}}

{{/*Validate Type validation */}}
{{- $allowedTypes := list "ClusterIP" "NodePort" -}}
{{- if not (has .type $allowedTypes ) -}}
{{- fail (dict 
    "errorKey" "type"
    "errorMessage" (printf "Invalid service type %s. Type must be one of %s" .type (join ", " $allowedTypes))| toJson) -}}
{{- end -}}
{{- end -}}