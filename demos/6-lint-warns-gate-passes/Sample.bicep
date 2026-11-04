// Deploys fine; the linter warns about the unused parameter (rule no-unused-params).
param location string = resourceGroup().location
param legacyName string

output site string = location
