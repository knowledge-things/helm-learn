#!/bin/sh

echo "Installing curl..."
apk update && apk add --no-cache curl


echo "Executing curl request to test-hook {{ .Release.Name }}"
curl http://{{ include "test-hook.fullname" . }}:{{ .Values.service.port }}
