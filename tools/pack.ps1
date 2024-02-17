$ErrorActionPreference = 'Stop'

Remove-Item -Force -Recurse  -ErrorAction SilentlyContinue ./dist | Out-Null
New-Item -ItemType Directory -Force ./dist | Out-Null

$git_hash = $(git describe --tags)

Compress-Archive -Force -CompressionLevel Optimal `
    -DestinationPath "./dist/fibocom-connect-fm350.$git_hash.zip" `
    -Path './*.cmd', './scripts', './screenshot', './*.md'

Copy-Item -Force `
    -Path './drivers/*' `
    -Destination './dist/'
