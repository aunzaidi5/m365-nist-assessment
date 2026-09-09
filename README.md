# Microsoft 365 NIST-Aligned Security Posture Assessment

A custom Microsoft 365 security assessment and reporting layer built on top of **M365-Assess**.

The project performs read-only Microsoft 365 technical assessment, maps the resulting findings to:

- **NIST SP 800-53 Rev. 5**
- **NIST Cybersecurity Framework (CSF) 2.0**

and presents the results through a custom **FastAPI web application**, interactive posture dashboard, evidence filters, remediation views, and downloadable assessment artifacts.

> **Important:** This project does not certify NIST compliance.  
> The displayed posture metric is a mapped-check pass rate across applicable technical checks, not a framework-wide compliance percentage.

---

## What the project does

The current assessment workflow provides:

- Full standard Microsoft 365 assessment through M365-Assess
- Microsoft device-code authentication
- Microsoft 365 configuration and security evidence collection
- NIST SP 800-53 Rev. 5 mapping
- NIST CSF 2.0 mapping
- Custom browser-based assessment workflow
- Interactive assessment progress
- Interactive posture score visualization
- Pass / Fail / Warning / Review filtering
- Risk-level filtering
- Findings search
- Expandable evidence and remediation details
- Excel and CSV evidence exports
- Provenance-aware assessment scope

---

## Architecture

```text
Microsoft 365 Tenant
        │
        ▼
M365-Assess
Read-only technical collection
        │
        ▼
Microsoft 365 checks + evidence
        │
        ▼
M365-Assess control registry
        │
        ├───────────────────────┐
        ▼                       ▼
NIST SP 800-53 Rev. 5       NIST CSF 2.0
        │                       │
        └───────────┬───────────┘
                    ▼
          Custom NIST Layer
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
Interactive HTML Report     Excel / CSV Evidence
```

---

## Web assessment experience

The project includes a custom FastAPI front end for running and reviewing an assessment.

```text
Connect Microsoft 365 tenant
            ↓
Microsoft authentication
            ↓
Collect Microsoft 365 evidence
            ↓
Evaluate Microsoft 365 controls
            ↓
Map findings to NIST
            ↓
Build assessment package
            ↓
Interactive NIST posture report
```

The generated report provides a high-level posture view first, while allowing an assessor to drill into individual findings and supporting technical evidence.

---

## Microsoft 365 assessment scope

When no `-Section` parameter is provided, the wrapper allows M365-Assess to execute its standard Microsoft 365 assessment scope rather than forcing an Identity-only run.

Standard assessment areas can include:

- Tenant
- Identity
- Licensing
- Email
- Intune
- Security
- Collaboration
- Power BI
- Hybrid

Specific sections can still be requested when a narrower assessment is required.

---

## Interactive report

The generated NIST report includes:

### Overall posture

A visual mapped-check pass-rate indicator based on assessed technical findings.

### Status views

Findings are categorized as:

- Pass
- Fail
- Warning
- Review

### Risk filtering

Assessment findings can be narrowed by severity.

### Search

Search across:

- Check IDs
- Microsoft 365 settings
- NIST mappings
- Evidence
- Remediation guidance

### Expandable evidence

Individual findings can be expanded to inspect:

- NIST SP 800-53 control mappings
- NIST CSF 2.0 mappings
- Observed configuration
- Expected configuration
- Recommended remediation

---

## How the posture score works

The posture metric is calculated as:

```text
Pass / (Pass + Fail + Warning)
```

`Review`, `Unknown`, and `Not Licensed` states are excluded from the denominator.

For example, the tool should **not** claim:

```text
73% NIST compliant
```

A more accurate description is:

```text
73% mapped-check pass rate
```

This distinction is important because Microsoft 365 technical configuration alone cannot establish compliance with an entire security framework.

---

## Requirements

### PowerShell

- PowerShell 7+
- M365-Assess 2.12.0 or newer recommended
- ImportExcel — optional, required only for XLSX output

Install:

```powershell
Install-Module M365-Assess -Scope CurrentUser
Install-Module ImportExcel -Scope CurrentUser
```

### Python

Create a virtual environment:

```bash
python -m venv .venv
source .venv/bin/activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

The web application uses:

- FastAPI
- Uvicorn
- Jinja2
- python-multipart

---

## Run the web application

From the project root:

```bash
source .venv/bin/activate
python -m uvicorn web.app:app --reload --host 127.0.0.1 --port 8000
```

Open:

```text
http://127.0.0.1:8000
```

Enter the tenant's primary Microsoft 365 domain:

```text
contoso.onmicrosoft.com
```

The application then guides the user through Microsoft authentication and assessment execution.

---

## Run directly from PowerShell

### Full standard Microsoft 365 assessment

```powershell
./Invoke-M365NistAssessment.ps1 `
    -TenantId 'contoso.onmicrosoft.com' `
    -UseDeviceCode `
    -OpenReport
```

No `-Section` parameter is required for the standard assessment scope.

### Identity-only assessment

```powershell
./Invoke-M365NistAssessment.ps1 `
    -TenantId 'contoso.onmicrosoft.com' `
    -Section Identity `
    -UseDeviceCode `
    -OpenReport
```

### Selected assessment areas

```powershell
./Invoke-M365NistAssessment.ps1 `
    -TenantId 'contoso.onmicrosoft.com' `
    -Section Identity,Security,Intune `
    -UseDeviceCode
```

---

## Re-process an existing M365-Assess assessment

An existing assessment directory can be processed without querying the tenant again:

```powershell
./Invoke-M365NistAssessment.ps1 `
    -ExistingAssessmentFolder '/path/to/Assessment_YYYYMMDD_HHMMSS_tenant' `
    -OpenReport
```

---

## Generated output

A web assessment produces a structure similar to:

```text
output/
└── web-runs/
    └── <assessment-id>/
        ├── Raw-M365-Assess/
        │   └── Assessment_.../
        │
        └── NIST_.../
            ├── NIST-Assessment.html
            ├── NIST-Findings.csv
            ├── NIST-SP800-53-Findings.csv
            ├── NIST-SP800-53-Family-Summary.csv
            ├── NIST-CSF-2.0-Findings.csv
            ├── NIST-CSF-2.0-Function-Summary.csv
            ├── NIST-Compliance-Matrix.xlsx
            └── assessment-metadata.json
```

Generated tenant evidence is excluded from Git through `.gitignore`.

---

## Project structure

```text
m365-nist-assessment/
│
├── Functions/
│   ├── Export-Nist80053Report.ps1
│   ├── Export-NistComplianceMatrix.ps1
│   ├── Export-NistCsfReport.ps1
│   ├── Export-NistHtmlReport.ps1
│   └── Get-NistMappedFindings.ps1
│
├── web/
│   ├── app.py
│   │
│   ├── static/
│   │   ├── app.js
│   │   └── styles.css
│   │
│   └── templates/
│       └── index.html
│
├── docs/
│
├── Invoke-M365NistAssessment.ps1
├── config.json
├── requirements.txt
└── README.md
```

---

## Design approach

The project intentionally does not rebuild the Microsoft 365 assessment engine.

M365-Assess handles platform-specific tasks including:

- Microsoft authentication
- Microsoft Graph collection
- Microsoft 365 configuration inspection
- Security checks
- Evidence collection
- CheckId generation
- Framework registry mappings

This project adds a custom layer around that information for:

1. NIST-focused findings
2. Assessment workflow automation
3. Interactive posture visualization
4. Evidence and remediation review
5. Framework-specific reporting
6. Excel and CSV evidence export

This separation keeps the custom implementation focused while allowing improvements in the upstream M365-Assess engine to be reused.

---

## Security and data handling

Microsoft 365 assessment data can contain sensitive information such as:

- User identifiers
- Administrative roles
- Conditional Access configuration
- Security configuration
- Tenant metadata
- Policy information

For that reason:

- assessment output is excluded from Git
- tenant evidence should never be committed to this public repository
- generated reports should be handled securely
- the custom web page does not collect the user's Microsoft password

Authentication is performed through Microsoft's authentication workflow.

---

## Framework interpretation boundary

This application evaluates technical Microsoft 365 configuration.

It does **not** assess every requirement within NIST SP 800-53 or NIST CSF 2.0.

Controls requiring evidence such as:

- organizational policies
- business processes
- physical security
- governance
- personnel controls
- architecture
- operational procedures
- non-Microsoft systems

require additional assessment methods such as:

- interviews
- workshops
- architecture review
- document review
- operational evidence review

---

## Upstream project

This project uses:

**M365-Assess — Galvnyz/M365-Assess**

M365-Assess is used as the Microsoft 365 technical assessment engine.

This project consumes its technical findings and framework registry instead of recreating the underlying Microsoft 365 collectors.

---

## Future framework expansion

The same architecture can be extended to create framework-specific assessment experiences for:

- ISO/IEC 27001
- CIS Microsoft 365 Foundations Benchmark
- SOC 2
- CMMC
- PCI DSS
- CISA SCuBA
- other framework mappings supported by the M365-Assess registry

The objective is to reuse a single Microsoft 365 evidence collection process while generating framework-specific posture views and reports.

---

## Project status

Current prototype capabilities:

- ✅ Full standard Microsoft 365 assessment path
- ✅ NIST SP 800-53 Rev. 5 mapping
- ✅ NIST CSF 2.0 mapping
- ✅ FastAPI assessment interface
- ✅ Microsoft device-code workflow
- ✅ Interactive progress experience
- ✅ Interactive posture dashboard
- ✅ Findings filtering
- ✅ Risk filtering
- ✅ Evidence search
- ✅ Expandable remediation details
- ✅ Excel and CSV export

---

## Disclaimer

This repository is a technical prototype and security-assessment automation project.

It should not be interpreted as an official Microsoft, NIST, M365-Assess, or employer-endorsed compliance product.
