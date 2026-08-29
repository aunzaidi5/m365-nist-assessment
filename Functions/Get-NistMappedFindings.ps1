function Get-NistMappedFindings {
    <#
    .SYNOPSIS
        Reads M365-Assess CSV evidence and returns only findings mapped to
        NIST SP 800-53 Rev. 5 and/or NIST CSF 2.0.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AssessmentFolder,

        [Parameter(Mandatory)]
        [string]$ControlsPath
    )

    function Get-PropertyValue {
        param(
            [object]$Object,
            [string]$Name,
            [object]$Default = ''
        )
        if ($null -eq $Object) { return $Default }
        $prop = $Object.PSObject.Properties[$Name]
        if ($null -eq $prop -or $null -eq $prop.Value) { return $Default }
        return $prop.Value
    }

    function Convert-MappingToText {
        param([object]$Mapping)

        if ($null -eq $Mapping) { return '' }

        $controlId = Get-PropertyValue -Object $Mapping -Name 'controlId' -Default ''
        if ($null -eq $controlId -or [string]::IsNullOrWhiteSpace([string]$controlId)) {
            return ''
        }

        return (@($controlId) |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ', '
    }

    if (-not (Test-Path $AssessmentFolder -PathType Container)) {
        throw "Assessment folder not found: $AssessmentFolder"
    }

    $registryPath = Join-Path $ControlsPath 'registry.json'
    if (-not (Test-Path $registryPath)) {
        throw "M365-Assess control registry not found: $registryPath"
    }

    $registryRaw = Get-Content $registryPath -Raw | ConvertFrom-Json
    $registry = @{}

    foreach ($check in @($registryRaw.checks)) {
        if ($check.checkId) {
            $registry[[string]$check.checkId] = $check
        }
    }

    # Optional risk-severity overlay from M365-Assess.
    $riskSeverity = @{}
    $riskPath = Join-Path $ControlsPath 'risk-severity.json'
    if (Test-Path $riskPath) {
        $riskRaw = Get-Content $riskPath -Raw | ConvertFrom-Json
        if ($riskRaw.checks) {
            foreach ($p in $riskRaw.checks.PSObject.Properties) {
                $riskSeverity[$p.Name] = [string]$p.Value
            }
        }
    }

    # Prefer the official assessment summary because it tells us which collector
    # CSVs completed successfully.
    $summaryFile = Get-ChildItem $AssessmentFolder -Filter '_Assessment-Summary*.csv' -File -ErrorAction SilentlyContinue |
        Select-Object -First 1

    $sources = @()

    if ($summaryFile) {
        foreach ($item in @(Import-Csv $summaryFile.FullName)) {
            $status = [string](Get-PropertyValue $item 'Status')
            $fileName = [string](Get-PropertyValue $item 'FileName')
            if ($status -ne 'Complete' -or [string]::IsNullOrWhiteSpace($fileName)) {
                continue
            }

            $csvPath = Join-Path $AssessmentFolder $fileName
            if (-not (Test-Path $csvPath -PathType Leaf)) {
                continue
            }

            $sources += [PSCustomObject]@{
                Path      = $csvPath
                Collector = [string](Get-PropertyValue $item 'Collector' ([IO.Path]::GetFileNameWithoutExtension($fileName)))
            }
        }
    }

    # Fallback for older/newer output layouts where the summary is absent or changed.
    if ($sources.Count -eq 0) {
        $sources = Get-ChildItem $AssessmentFolder -Filter '*.csv' -File -Recurse |
            Where-Object { $_.Name -notlike '_Assessment-Summary*' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Path      = $_.FullName
                    Collector = $_.BaseName
                }
            }
    }

    $result = [System.Collections.Generic.List[object]]::new()

    foreach ($source in $sources) {
        $rows = @(Import-Csv $source.Path)
        if ($rows.Count -eq 0) { continue }

        $columnNames = @($rows[0].PSObject.Properties.Name)
        if ($columnNames -notcontains 'CheckId') { continue }

        foreach ($row in $rows) {
            $checkId = [string](Get-PropertyValue $row 'CheckId')
            if ([string]::IsNullOrWhiteSpace($checkId)) { continue }

            # M365-Assess can emit child setting IDs such as CHECK-001.1 while
            # the registry is keyed by the base check ID.
            $baseCheckId = $checkId -replace '\.\d+$', ''
            if (-not $registry.ContainsKey($baseCheckId)) { continue }

            $entry = $registry[$baseCheckId]
            $frameworks = Get-PropertyValue $entry 'frameworks' $null
            if ($null -eq $frameworks) { continue }

            $nist80053Map = Get-PropertyValue $frameworks 'nist-800-53' $null
            $nistCsfMap   = Get-PropertyValue $frameworks 'nist-csf' $null

            $nist80053 = Convert-MappingToText $nist80053Map
            $nistCsf   = Convert-MappingToText $nistCsfMap

            if ([string]::IsNullOrWhiteSpace($nist80053) -and
                [string]::IsNullOrWhiteSpace($nistCsf)) {
                continue
            }

            $rowRemediation = [string](Get-PropertyValue $row 'Remediation')
            $registryRemediation = [string](Get-PropertyValue $entry 'remediation')
            $remediation = if (-not [string]::IsNullOrWhiteSpace($rowRemediation)) {
                $rowRemediation
            } else {
                $registryRemediation
            }

            $severity = if ($riskSeverity.ContainsKey($baseCheckId)) {
                $riskSeverity[$baseCheckId]
            } else {
                'Medium'
            }

            $result.Add([PSCustomObject][ordered]@{
                CheckId          = $checkId
                BaseCheckId      = $baseCheckId
                Setting          = [string](Get-PropertyValue $row 'Setting')
                Category         = [string](Get-PropertyValue $row 'Category' (Get-PropertyValue $entry 'category'))
                Status           = [string](Get-PropertyValue $row 'Status' 'Unknown')
                RiskSeverity     = $severity
                Source           = [string]$source.Collector
                ObservedValue    = [string](Get-PropertyValue $row 'ObservedValue')
                ExpectedValue    = [string](Get-PropertyValue $row 'ExpectedValue')
                EvidenceSource   = [string](Get-PropertyValue $row 'EvidenceSource')
                EvidenceTimestamp= [string](Get-PropertyValue $row 'EvidenceTimestamp')
                CollectionMethod = [string](Get-PropertyValue $row 'CollectionMethod')
                Confidence       = [string](Get-PropertyValue $row 'Confidence')
                Limitations      = [string](Get-PropertyValue $row 'Limitations')
                Remediation      = $remediation
                Nist80053        = $nist80053
                NistCsf          = $nistCsf
            })
        }
    }

    # Deduplicate only exact repeated finding identities. Keep child findings and
    # collector-specific evidence separate.
    $result |
        Sort-Object CheckId, Setting, Source -Unique
}
