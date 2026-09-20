$root = 'D:\Opencode Projects\ViaNova'

# EN -> TR page mapping
$map = @{
  '/' = '/tr/'
  '/about/' = '/tr/hakkimizda/'
  '/services/' = '/tr/hizmetler/'
  '/pricing/' = '/tr/fiyatlar/'
  '/countries/' = '/tr/ulkeler/'
  '/countries/austria/' = '/tr/ulkeler/avusturya/'
  '/countries/belgium/' = '/tr/ulkeler/belcika/'
  '/countries/bulgaria/' = '/tr/ulkeler/bulgaristan/'
  '/countries/canada/' = '/tr/ulkeler/kanada/'
  '/countries/estonia/' = '/tr/ulkeler/estonya/'
  '/countries/germany/' = '/tr/ulkeler/almanya/'
  '/countries/latvia/' = '/tr/ulkeler/letonya/'
  '/countries/lithuania/' = '/tr/ulkeler/litvanya/'
  '/countries/moldova/' = '/tr/ulkeler/moldova/'
  '/countries/netherlands/' = '/tr/ulkeler/hollanda/'
  '/countries/poland/' = '/tr/ulkeler/polonya/'
  '/countries/romania/' = '/tr/ulkeler/romanya/'
  '/countries/russia/' = '/tr/ulkeler/rusya/'
  '/countries/switzerland/' = '/tr/ulkeler/isvicre/'
  '/countries/united-kingdom/' = '/tr/ulkeler/ingiltere/'
  '/countries/united-states/' = '/tr/ulkeler/abd/'
  '/consultation/' = '/tr/danismanlik/'
  '/contact/' = '/tr/iletisim/'
  '/faq/' = '/tr/sss/'
  '/how-it-works/' = '/tr/nasil-calisir/'
  '/pay/' = '/tr/odeme/'
  '/success-stories/' = '/tr/basari-hikayeleri/'
}

$count = 0

foreach ($enPath in $map.Keys) {
  $trPath = $map[$enPath]
  $enFile = Join-Path $root ($enPath.TrimStart('/') + '/index.html')
  $trFile = Join-Path $root ($trPath.TrimStart('/') + '/index.html')

  # Add hreflang to EN file
  if (Test-Path $enFile) {
    $c = Get-Content $enFile -Raw -Encoding UTF8
    $enFull = "https://vianova.com$enPath"
    $trFull = "https://vianova.com$trPath"
    $hreflangBlock = "`n<link rel=`"alternate`" hreflang=`"en`" href=`"$enFull`">`n<link rel=`"alternate`" hreflang=`"tr`" href=`"$trFull`">`n<link rel=`"alternate`" hreflang=`"x-default`" href=`"$enFull`">"

    # Remove existing hreflang tags if any
    $c = $c -replace '(?m)\s*<link rel="alternate" hreflang="[^"]*" href="[^"]*">\s*', "`n"

    # Insert before </head>
    $c = $c -replace '</head>', "$hreflangBlock`n</head>"

    [System.IO.File]::WriteAllText($enFile, $c, [System.Text.UTF8Encoding]::new($false))
    $count++
  }

  # Add hreflang to TR file
  if (Test-Path $trFile) {
    $c = Get-Content $trFile -Raw -Encoding UTF8
    $enFull = "https://vianova.com$enPath"
    $trFull = "https://vianova.com$trPath"
    $hreflangBlock = "`n<link rel=`"alternate`" hreflang=`"en`" href=`"$enFull`">`n<link rel=`"alternate`" hreflang=`"tr`" href=`"$trFull`">`n<link rel=`"alternate`" hreflang=`"x-default`" href=`"$enFull`">"

    # Remove existing hreflang tags if any
    $c = $c -replace '(?m)\s*<link rel="alternate" hreflang="[^"]*" href="[^"]*">\s*', "`n"

    # Insert before </head>
    $c = $c -replace '</head>', "$hreflangBlock`n</head>"

    [System.IO.File]::WriteAllText($trFile, $c, [System.Text.UTF8Encoding]::new($false))
    $count++
  }
}

Write-Host "Hreflang tags added/updated in $count files"
