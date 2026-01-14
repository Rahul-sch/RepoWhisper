#!/bin/bash
set -e

# RepoWhisper Security Audit Script
# Scans the repository for potential secrets and security issues

echo "🔍 RepoWhisper Security Audit"
echo "=============================="

ISSUES_FOUND=0

# Function to report issues
report_issue() {
    echo "❌ ISSUE: $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

# Function to report check passed
report_ok() {
    echo "✅ $1"
}

echo ""
echo "Checking for API keys and secrets..."

# Check for Groq API keys (gsk_...)
if grep -rE "gsk_[A-Za-z0-9]{20,}" --include="*.py" --include="*.swift" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "audit_secrets.sh"; then
    report_issue "Found Groq API key pattern (gsk_...)"
else
    report_ok "No Groq API keys found"
fi

# Check for OpenAI API keys (sk-...)
if grep -rE "sk-[A-Za-z0-9]{20,}" --include="*.py" --include="*.swift" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "audit_secrets.sh"; then
    report_issue "Found OpenAI API key pattern (sk-...)"
else
    report_ok "No OpenAI API keys found"
fi

# Check for Supabase URLs
if grep -rE "supabase\.co" --include="*.py" --include="*.swift" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "audit_secrets.sh"; then
    report_issue "Found Supabase URL reference"
else
    report_ok "No Supabase URLs found"
fi

# Check for JWT-like tokens (eyJ...)
if grep -rE "eyJ[A-Za-z0-9_-]{50,}" --include="*.py" --include="*.swift" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v "audit_secrets.sh"; then
    report_issue "Found JWT-like token pattern (eyJ...)"
else
    report_ok "No JWT tokens found in code"
fi

echo ""
echo "Checking for tracked .env files..."

# Check for tracked .env files
if git ls-files | grep -E "\.env$" 2>/dev/null; then
    report_issue "Found tracked .env file(s)"
else
    report_ok "No .env files tracked in git"
fi

echo ""
echo "Checking for dev/testing mode references in Swift..."

# Check for devMode/testingMode in Swift files
if grep -rE "devMode|isDevMode|testingMode" --include="*.swift" . 2>/dev/null | grep -v "audit_secrets.sh"; then
    report_issue "Found devMode/testingMode reference in Swift code"
else
    report_ok "No devMode/testingMode references in Swift"
fi

echo ""
echo "=============================="
if [ $ISSUES_FOUND -eq 0 ]; then
    echo "✅ Security audit PASSED - no issues found"
    exit 0
else
    echo "❌ Security audit FAILED - $ISSUES_FOUND issue(s) found"
    exit 1
fi
