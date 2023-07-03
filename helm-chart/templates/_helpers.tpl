{{/*
Copyright IBM Inc. All Rights Reserved.
SPDX-License-Identifier: Apache-2.0
Authors:
  Vassilis Vassiliadis
*/}}

{{/*If user doesn't specify a "host", builds one by extracting the canonical route of the cluster, then
prefixing it with "${user-prefix}-${namespace}." */}}
{{/*This is equivalent to oc get ingress.config.openshift.io cluster -o jsonpath="{.spec.domain}" */}}
{{/* Helm does not contact kubernetes when not actively installing/updating */}}
{{- define "builddomain" -}}
{{- $canonicalroute := "" -}}
{{- if .host -}}
{{-   printf "%s" .host }}
{{- else -}}
{{-   if .domain -}}
{{-     $canonicalroute = .domain -}}
{{-   else -}}
{{-     $canonicalroute = (lookup "config.openshift.io/v1" "Ingress" "" "cluster").spec.domain }}
{{-   end -}}
{{-     printf "%s.%s" .prefix $canonicalroute -}}
{{-   end -}}
{{- end -}}


{{- define "host.workflowStack" }}
{{- template "builddomain" (dict "prefix" .Values.routePrefix "domain" .Values.clusterRouteDomain "host" "")}}
{{- end }}

{{/*Generates a random password if secret does not exist, reuses the password if the secret already exists*/}}
{{/* Helm does not contact kubernetes when not actively installing/updating */}}
{{- define "secrets.databaseMongoUserPassSecret" }}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.datastoreMongoDBSecretName) | default dict }}
{{- $data := (get $secret "data") | default dict }}
{{- $pass := (get $data "password") | default (randAlphaNum 64 | b64enc) }}
{{- printf "%s" $pass | quote }}
{{- end }}


{{/*Generates a random password if secret does not exist, reuses the password if the secret already exists*/}}
{{/* Helm does not contact kubernetes when not actively installing/updating */}}
{{- define "secrets.authenticationSeed" }}
{{- $secret := (lookup "v1" "Secret" .Release.Namespace .Values.oauthProxySeedSecretName) | default dict }}
{{- $data := (get $secret "data") | default dict }}
{{- $pass := (get $data "password") | default (randAlphaNum 64 | b64enc) }}
{{- printf "%s" $pass | quote }}
{{- end }}

{{/*Groups together, existing imagePullSecrets in ConfigMap, and those defined in the helm chart*/}}
{{/* Helm does not contact kubernetes when not actively installing/updating */}}
{{- define "st4sdRuntimeService.imagePullSecrets" }}
{{- $imagePullSecrets := list }}
{{- $cm := lookup "v1" "ConfigMap" .Release.Namespace .Values.runtimeServiceConfigConfigMapName }}
{{- $fromChart := list }}
{{- if $.Values.useImagePullSecretWorkflowStack }}
{{-     $fromChart = append $fromChart .Values.workflowImagePullSecret }}
{{- end}}
{{- if $.Values.useImagePullSecretContribApplications }}
{{-     $fromChart = append $fromChart .Values.contribApplicationsImagePullSecret }}
{{- end }}
{{- if $.Values.useImagePullSecretCommunityApplications }}
{{-     $fromChart = append $fromChart .Values.communityApplicationsImagePullSecret }}
{{- end }}
{{- if $cm }}
    {{- $data := $cm.data }}
    {{- $config := get $data "config.json" | fromJson }}
    {{- $imagePullSecrets = $config.imagePullSecrets }}
{{- end}}
{{- $imagePullSecrets = concat $imagePullSecrets .Values.experimentImagePullSecrets $fromChart | uniq }}
{{- $quoted := list }}
{{- range $imagePullSecrets }}
{{-   $quoted = printf . | quote | append $quoted -}}
{{- end }}
{{- $text := $quoted | join "," }}
{{- printf $text }}
{{- end }}


{{/*Decides the value of the field gitsecret-oauth in the st4sd-runtime-config secret

If .Values.installGithubSecretOAuth is set, then it echoes that name
It attempts to peek at the existing st4sd-runtime-service ConfigMap.
    If it does not exist, it returns null
    If the field config.json['gitsecret-oauth'] does not exist, it returns null
    If the secret called config.json['gitsecret-oauth'] is unmanaged by helm, it returns null
    At this point, we know that the ConfigMap points to a secret which is not managed by Helm.
    We can infer that a ST4SD namespace-admin added it post installation and that they probably
    want to keep using it. Therefore we just print its name so that the configmap can re-use it
*/}}
{{- define "secret.gitSecretOAuthName" }}
{{- if .Values.installGithubSecretOAuth  }}
    {{- print .Values.gitOAuthSecretName -}}
{{- else }}
    {{- $cm := lookup "v1" "ConfigMap" .Release.Namespace .Values.runtimeServiceConfigConfigMapName }}
    {{- if $cm }}
        {{- $data := $cm.data | default dict }}
        {{- $config := get $data "config.json" | default "null" | fromJson }}
        {{- if $config }}
            {{- $secret_name := get $config "gitsecret-oauth" }}
            {{- if $secret_name }}
                {{- $secret := lookup "v1" "Secret" .Release.Namespace $secret_name }}
                {{- if $secret }}
                    {{- $label := get ($secret.metadata.labels | default dict) "app.kubernetes.io/managed-by" }}
                    {{- if ne $label "Helm" -}}
                        {{- /*VV: The ConfigMap points to a secret which is NOT managed by helm 
                        this means that a ST4SD-namespace admin added the secret post-installation.
                        Re-use the secret. If Helm managed the secret, then we should remove it 
                        i.e. do not print its name.*/}}
                        {{- print $secret_name -}}
                    {{- end -}}
                {{- end }}
            {{- end}}
        {{- end }}
    {{- end }}
{{- end }}
{{- end }}
