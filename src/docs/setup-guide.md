# Entra ID (Azure AD) + Salesforce SSO Integration Setup Guide

This guide walks you through setting up **Single Sign-On (SSO)** between **Microsoft Entra ID (Azure Active Directory)** and **Salesforce**, including required configuration and secure storage of integration details.

---

## 1. Configure SAML Single Sign-On in Salesforce

1. In Salesforce Setup, go to **Single Sign-On Settings**
2. Click the **Edit** button
3. Check  **SAML Enabled**
4. Click **Save**

---

## 2. Upload Metadata from Entra ID

1. Back on the **Single Sign-On Settings** page, click **New from Metadata File**
2. Click **Choose File** and select the **metadata XML file** downloaded from Entra ID (Azure Portal)
3. Click **Create**

## 3. Store Integration Details Securely

Create a **Custom Setting (Protected)** or use **Custom Metadata Types** to store Entra app credentials securely.

### Custom Setting Fields:
- `Client_ID__c`
- `Client_Secret__c`
- `Tenant_ID__c`
- `Scope__c` (e.g., `User.Read`, `openid`, etc.)
- `Token_Endpoint__c`

> **Make it protected** to ensure it's not accessible to non-secure packages.

Alternatively, use **Named Credentials** (recommended for secret management).


##  4. Add Entra Base URL to Remote Site Settings or Use Named Credentials

### Option A: Remote Site Settings

1. In Salesforce Setup, go to **Remote Site Settings**
2. Click **New Remote Site**
3. Name: `Entra_API`
4. URL: `https://login.microsoftonline.com` or your tenant-specific endpoint
5. Save

### Option B: Named Credential (Recommended)

1. In Setup, go to **Named Credentials**
2. Click **New Named Credential**
3. Set the following:
   - Label: `EntraToken`
   - Name: `EntraToken`
   - URL: `https://login.microsoftonline.com`
   - Identity Type: `Named Principal`
   - Authentication Protocol: `OAuth 2.0`
   - Scope: `openid profile User.Read`
   - Client ID and Client Secret: (from Azure App)
   - Token Endpoint URL:  
     `https://login.microsoftonline.com/<TENANT_ID>/oauth2/v2.0/token`
4. Save

## Final Tips

- Always avoid hardcoding secrets in Apex
- Use `Named Credentials` or `Custom Settings` to fetch secrets securely
- Use `Remote Site Settings` only if not using Named Credentials
- Add test classes for all Apex integrations



