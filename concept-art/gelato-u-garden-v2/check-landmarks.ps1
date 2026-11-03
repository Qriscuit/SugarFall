$ErrorActionPreference='Stop'
$geometry=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'geometry.json') -Raw | ConvertFrom-Json
$regions=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'landmark-regions.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Drawing
$checks=0
$records=@()
foreach ($region in $regions.regions) {
    $p=$region.pixel_rect
    $r=[System.Drawing.RectangleF]::new([single](-5200+$p[0]*10400/1254),[single](-9650+$p[1]*10400/1254),[single]($p[2]*10400/1254),[single]($p[3]*10400/1254))
    foreach ($node in $geometry.nodes) {
        $k=$node.keepout_rect
        $tile=[System.Drawing.RectangleF]::new([single]$k[0],[single]$k[1],[single]$k[2],[single]$k[3])
        if ($r.IntersectsWith($tile)) { throw ('Landmark '+$region.name+' overlaps node '+($node.id -join ',')) }
        $checks++
    }
    foreach ($link in $geometry.links) {
        for ($i=1; $i -lt $link.points.Count; $i++) {
            $a=$link.points[$i-1]; $b=$link.points[$i]; $pad=$link.keepout_radius
            $lineBounds=[System.Drawing.RectangleF]::new([single]([Math]::Min($a[0],$b[0])-$pad),[single]([Math]::Min($a[1],$b[1])-$pad),[single]([Math]::Abs($a[0]-$b[0])+2*$pad),[single]([Math]::Abs($a[1]-$b[1])+2*$pad))
            if ($r.IntersectsWith($lineBounds)) { throw ('Landmark '+$region.name+' overlaps padded link bounds '+($link.from -join ',')+' -> '+($link.to -join ',')) }
            $checks++
        }
    }
    $records += [ordered]@{name=$region.name;pixel_rect=$p;world_rect=@($r.X,$r.Y,$r.Width,$r.Height)}
}
$result=[ordered]@{passed=$true;checks=$checks;failed=0;tile_selection_keepout=280;link_keepout_radius=30;actual_landmark_regions=$records}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'landmark-validation.json'),($result|ConvertTo-Json -Depth 6))
Write-Output ('Landmark clearance: '+$checks+' passed, 0 failed.')
