#!/usr/bin/env pwsh

# Deploy corrected RPC functions to Supabase
# This script reads the SQL migration files and applies them directly to the database

$projectId = "znvsyzstmxhqvdkkmgdt"
$apiUrl = "https://$projectId.supabase.co"

Write-Host "🚀 Deploying corrected RPC functions to Supabase..."
Write-Host ""

# Read the migration files
$swap_remove_sql = Get-Content "supabase/migrations/20260223123000_add_swap_and_remove_rpcs.sql" -Raw
$equip_sql = Get-Content "supabase/migrations/20260223124000_add_equip_rpcs.sql" -Raw

Write-Host "✅ Migrations loaded"
Write-Host ""
Write-Host "📋 Next steps:"
Write-Host ""
Write-Host "1. Open Supabase SQL Editor:"
Write-Host "   https://app.supabase.com/projects/$projectId/sql/new"
Write-Host ""
Write-Host "2. Copy and paste the corrected functions below into the SQL editor:"
Write-Host ""
Write-Host "------- Paste everything below -------"
Write-Host ""
Write-Host $equip_sql
Write-Host ""
Write-Host $swap_remove_sql
Write-Host ""
Write-Host "------- End of SQL -------"
Write-Host ""
Write-Host "3. Click 'Run' to deploy"
Write-Host ""
Write-Host "⚠️  NOTE: The functions will be replaced with corrected versions"
