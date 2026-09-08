# Regenerate both figures after editing model.json or style.json.
# All Python arguments are forwarded, e.g. .\build.ps1 --config variant.json.
$ErrorActionPreference = 'Stop'
$projectPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $projectPython)) {
    $projectPython = (Get-Command python -ErrorAction Stop).Source
}
& $projectPython (Join-Path $PSScriptRoot 'build.py') @args
if ($LASTEXITCODE -ne 0) { throw "PlotNeuralNet build failed ($LASTEXITCODE)." }
