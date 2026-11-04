// The same template with the parameter used: no linter diagnostics.
param location string = resourceGroup().location
param legacyName string

output site string = '${location}/${legacyName}'
