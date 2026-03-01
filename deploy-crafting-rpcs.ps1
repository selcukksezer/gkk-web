#!/usr/bin/env pwsh

# Deploy crafting system migrations to Supabase
# This script helps deploy the new craft_queue table and RPCs

$projectId = "znvsyzstmxhqvdkkmgdt"
$apiUrl = "https://$projectId.supabase.co"

Write-Host "🚀 Deploying crafting system migrations to Supabase..."
Write-Host ""

# Read the migration file
$migration_sql = Get-Content "supabase/migrations/20260301_020000_create_craft_queue_and_rpcs.sql" -Raw

Write-Host "✅ Migration loaded (craft_queue table + 4 RPCs)"
Write-Host ""
Write-Host "📋 Next steps:"
Write-Host ""
Write-Host "1. Open Supabase SQL Editor:"
Write-Host "   https://app.supabase.com/projects/$projectId/sql/new"
Write-Host ""
Write-Host "2. Copy and paste the SQL below into the SQL editor:"
Write-Host ""
Write-Host "------- Paste everything below -------"
Write-Host ""
Write-Host $migration_sql
Write-Host ""
Write-Host "------- End of SQL -------"
Write-Host ""
Write-Host "3. Click 'Run' to deploy"
Write-Host ""
Write-Host "⚠️  NOTE: This migration creates:"
Write-Host "   - craft_queue table"
Write-Host "   - get_craft_queue RPC"
Write-Host "   - get_craft_recipes RPC"
Write-Host "   - craft_item_async RPC"
Write-Host "   - claim_crafted_item RPC"
Write-Host "   - RLS policies for craft_queue table"
Write-Host ""
Write-Host "💡 After deployment, restart the dev server: npm run dev"
