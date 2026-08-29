function Export-NistHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Findings,

        [Parameter()]
        [object[]]$Nist80053Summary = @(),

        [Parameter()]
        [object[]]$NistCsfSummary = @(),

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [string]$TenantLabel = 'Tenant',

        [Parameter()]
        [string[]]$Sections = @('Identity'),

        [Parameter()]
        [string]$SourceAssessmentFolder = ''
    )

    function ConvertTo-HtmlSafe([object]$Value) {
        if ($null -eq $Value) { return '' }
        [System.Net.WebUtility]::HtmlEncode([string]$Value)
    }

    function StatusClass([string]$Status) {
        switch ($Status.ToLowerInvariant()) {
            'pass'    { 'pass' }
            'fail'    { 'fail' }
            'warning' { 'warning' }
            'review'  { 'review' }
            default   { 'other' }
        }
    }

    $total = $Findings.Count
    $mapped80053 = @($Findings | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Nist80053) }).Count
    $mappedCsf = @($Findings | Where-Object { -not [string]::IsNullOrWhiteSpace($_.NistCsf) }).Count
    $pass = @($Findings | Where-Object Status -eq 'Pass').Count
    $fail = @($Findings | Where-Object Status -eq 'Fail').Count
    $warning = @($Findings | Where-Object Status -eq 'Warning').Count
    $review = @($Findings | Where-Object Status -eq 'Review').Count

    $denominator = $pass + $fail + $warning
    $mappedCheckPassRate = if ($denominator -gt 0) {
        [math]::Round(($pass / $denominator) * 100, 1)
    } else {
        0
    }

    $rows80053 = @($Nist80053Summary | ForEach-Object {
        "<tr><td><strong>$(ConvertTo-HtmlSafe $_.Family)</strong></td><td>$(ConvertTo-HtmlSafe $_.FamilyName)</td><td>$($_.UniqueControlsSeen)</td><td>$($_.MappedFindings)</td><td>$($_.Pass)</td><td>$($_.Fail)</td><td>$($_.Warning)</td><td>$($_.Review)</td></tr>"
    }) -join [Environment]::NewLine

    $rowsCsf = @($NistCsfSummary | ForEach-Object {
        "<tr><td><strong>$(ConvertTo-HtmlSafe $_.Function)</strong></td><td>$(ConvertTo-HtmlSafe $_.FunctionName)</td><td>$($_.UniqueSubcategoriesSeen)</td><td>$($_.MappedFindings)</td><td>$($_.Pass)</td><td>$($_.Fail)</td><td>$($_.Warning)</td><td>$($_.Review)</td></tr>"
    }) -join [Environment]::NewLine

    $findingRows = @($Findings | Sort-Object @{Expression={
        switch ($_.Status) { 'Fail' {0}; 'Warning' {1}; 'Review' {2}; 'Pass' {3}; default {4} }
    }}, RiskSeverity, CheckId | ForEach-Object {
        $class = StatusClass $_.Status
        @"
<tr>
  <td><code>$(ConvertTo-HtmlSafe $_.CheckId)</code></td>
  <td>$(ConvertTo-HtmlSafe $_.Setting)</td>
  <td><span class="status $class">$(ConvertTo-HtmlSafe $_.Status)</span></td>
  <td>$(ConvertTo-HtmlSafe $_.RiskSeverity)</td>
  <td>$(ConvertTo-HtmlSafe $_.Nist80053)</td>
  <td>$(ConvertTo-HtmlSafe $_.NistCsf)</td>
  <td>$(ConvertTo-HtmlSafe $_.ObservedValue)</td>
  <td>$(ConvertTo-HtmlSafe $_.ExpectedValue)</td>
  <td>$(ConvertTo-HtmlSafe $_.Remediation)</td>
</tr>
"@
    }) -join [Environment]::NewLine

    $generated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $sectionsText = $Sections -join ', '

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>NIST M365 Assessment - $(ConvertTo-HtmlSafe $TenantLabel)</title>
<style>
:root {
  --bg:#f6f8fb; --panel:#ffffff; --text:#182230; --muted:#667085;
  --line:#e4e7ec; --accent:#174ea6; --accent2:#0b6bcb;
  --pass-bg:#ecfdf3; --pass:#027a48; --fail-bg:#fef3f2; --fail:#b42318;
  --warn-bg:#fffaeb; --warn:#b54708; --review-bg:#eff8ff; --review:#175cd3;
}
* { box-sizing:border-box; }
body { margin:0; font-family:Inter,Segoe UI,Arial,sans-serif; background:var(--bg); color:var(--text); }
.container { max-width:1500px; margin:0 auto; padding:34px; }
.header { background:linear-gradient(120deg,#0b2347,#174ea6); color:white; padding:34px; border-radius:18px; }
.header h1 { margin:0 0 8px; font-size:32px; }
.header p { margin:5px 0; opacity:.9; }
.notice { margin:22px 0; background:#fff7ed; border:1px solid #fed7aa; border-left:5px solid #f79009; padding:16px 18px; border-radius:10px; }
.cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr)); gap:14px; margin:22px 0; }
.card { background:var(--panel); border:1px solid var(--line); border-radius:14px; padding:18px; }
.card .label { color:var(--muted); font-size:13px; }
.card .value { font-size:28px; font-weight:750; margin-top:6px; }
section { background:var(--panel); border:1px solid var(--line); border-radius:14px; padding:22px; margin:18px 0; }
h2 { margin-top:0; }
.small { color:var(--muted); font-size:13px; }
.table-wrap { overflow:auto; border:1px solid var(--line); border-radius:10px; }
table { border-collapse:collapse; width:100%; min-width:800px; }
th,td { border-bottom:1px solid var(--line); padding:10px 12px; text-align:left; vertical-align:top; font-size:13px; }
th { background:#f9fafb; position:sticky; top:0; z-index:1; }
code { white-space:nowrap; }
.status { display:inline-block; padding:3px 8px; border-radius:999px; font-weight:650; font-size:12px; }
.status.pass { background:var(--pass-bg); color:var(--pass); }
.status.fail { background:var(--fail-bg); color:var(--fail); }
.status.warning { background:var(--warn-bg); color:var(--warn); }
.status.review { background:var(--review-bg); color:var(--review); }
.status.other { background:#f2f4f7; color:#344054; }
.footer { color:var(--muted); font-size:12px; margin:24px 3px; }
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>Microsoft 365 NIST Posture Assessment</h1>
    <p><strong>Tenant:</strong> $(ConvertTo-HtmlSafe $TenantLabel)</p>
    <p><strong>Scope:</strong> $(ConvertTo-HtmlSafe $sectionsText) &nbsp; | &nbsp; <strong>Generated:</strong> $(ConvertTo-HtmlSafe $generated)</p>
  </div>

  <div class="notice">
    <strong>Interpretation boundary:</strong>
    This report shows Microsoft 365 / Entra technical findings produced by M365-Assess
    and mapped to NIST SP 800-53 Rev. 5 and NIST CSF 2.0. It is not a formal NIST
    compliance certification and does not assess every control in either framework.
  </div>

  <div class="cards">
    <div class="card"><div class="label">NIST-mapped findings</div><div class="value">$total</div></div>
    <div class="card"><div class="label">Mapped to SP 800-53</div><div class="value">$mapped80053</div></div>
    <div class="card"><div class="label">Mapped to CSF 2.0</div><div class="value">$mappedCsf</div></div>
    <div class="card"><div class="label">Pass</div><div class="value">$pass</div></div>
    <div class="card"><div class="label">Fail</div><div class="value">$fail</div></div>
    <div class="card"><div class="label">Warning</div><div class="value">$warning</div></div>
    <div class="card"><div class="label">Review</div><div class="value">$review</div></div>
    <div class="card"><div class="label">Mapped-check pass rate*</div><div class="value">$mappedCheckPassRate%</div></div>
  </div>

  <section>
    <h2>NIST SP 800-53 Rev. 5 — mapped technical findings</h2>
    <p class="small">Counts below describe findings and control IDs observed in this M365 assessment scope; they are not framework-wide compliance scores.</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Family</th><th>Name</th><th>Unique controls seen</th><th>Mapped findings</th><th>Pass</th><th>Fail</th><th>Warning</th><th>Review</th></tr></thead>
        <tbody>$rows80053</tbody>
      </table>
    </div>
  </section>

  <section>
    <h2>NIST CSF 2.0 — mapped technical findings</h2>
    <p class="small">CSF mappings are grouped by Govern, Identify, Protect, Detect, Respond and Recover.</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Function</th><th>Name</th><th>Unique subcategories seen</th><th>Mapped findings</th><th>Pass</th><th>Fail</th><th>Warning</th><th>Review</th></tr></thead>
        <tbody>$rowsCsf</tbody>
      </table>
    </div>
  </section>

  <section>
    <h2>Detailed NIST findings</h2>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Check ID</th><th>Setting</th><th>Status</th><th>Risk</th>
            <th>NIST SP 800-53</th><th>NIST CSF 2.0</th>
            <th>Observed</th><th>Expected</th><th>Remediation</th>
          </tr>
        </thead>
        <tbody>$findingRows</tbody>
      </table>
    </div>
  </section>

  <div class="footer">
    <p>* Mapped-check pass rate = Pass / (Pass + Fail + Warning). Review/Unknown/Not Licensed states are excluded. This is not a NIST compliance percentage.</p>
    <p>Source M365-Assess folder: $(ConvertTo-HtmlSafe $SourceAssessmentFolder)</p>
  </div>
</div>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding utf8
    return $Path
}

