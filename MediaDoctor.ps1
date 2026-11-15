param([string]$FilePath)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $ScriptDir 'media-doctor.config.json'
$config = @{}
if (Test-Path -LiteralPath $configPath) {
    try { $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $config = @{} }
}
function Resolve-CommandPath([string]$configured, [string[]]$candidates, [string]$commandName) {
    if ($configured -and (Test-Path -LiteralPath $configured)) { return $configured }
    foreach ($p in $candidates) { if ($p -and (Test-Path -LiteralPath $p)) { return $p } }
    $cmd = Get-Command $commandName -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return ''
}
$ffprobe = Resolve-CommandPath ([string]$config.ffprobe) @("$env:ProgramFiles\ffmpeg\bin\ffprobe.exe", "${env:ProgramFiles(x86)}\ffmpeg\bin\ffprobe.exe") 'ffprobe.exe'
$pot = Resolve-CommandPath ([string]$config.potplayer) @("$env:ProgramFiles\DAUM\PotPlayer\PotPlayerMini64.exe", "${env:ProgramFiles(x86)}\DAUM\PotPlayer\PotPlayerMini64.exe") 'PotPlayerMini64.exe'
$madvrScript = [string]$config.madvrProfileScript
$presets = @('7.1.2','5.1','2.0')
$videoPresets = @('跟随 PotPlayer 预设（推荐）','自动（按片源）','madVR 电影 SDR','madVR 老片 1080p','MPC-VR 10bit HDR')
if (-not $ffprobe) { [System.Windows.Forms.MessageBox]::Show('找不到 ffprobe.exe。请安装 ffmpeg，或在 media-doctor.config.json 中设置 ffprobe。') | Out-Null }
if (-not $pot) { [System.Windows.Forms.MessageBox]::Show('找不到 PotPlayerMini64.exe。请在 media-doctor.config.json 中设置 potplayer。') | Out-Null }

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = '片源检测 - 音频/画质推荐'
$form.Size = New-Object System.Drawing.Size(920, 680)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(760, 560)
$form.AllowDrop = $true
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = '视频文件：'
$lbl.Location = New-Object System.Drawing.Point(15, 18)
$lbl.AutoSize = $true
$form.Controls.Add($lbl)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(90, 15)
$txtPath.Size = New-Object System.Drawing.Size(640, 28)
$txtPath.Anchor = 'Top,Left,Right'
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = '浏览...'
$btnBrowse.Location = New-Object System.Drawing.Point(740, 13)
$btnBrowse.Size = New-Object System.Drawing.Size(75, 30)
$btnBrowse.Anchor = 'Top,Right'
$form.Controls.Add($btnBrowse)

$btnAnalyze = New-Object System.Windows.Forms.Button
$btnAnalyze.Text = '开始检测'
$btnAnalyze.Location = New-Object System.Drawing.Point(15, 55)
$btnAnalyze.Size = New-Object System.Drawing.Size(100, 32)
$form.Controls.Add($btnAnalyze)

$lblPreset = New-Object System.Windows.Forms.Label
$lblPreset.Text = '音频预设：'
$lblPreset.Location = New-Object System.Drawing.Point(135, 63)
$lblPreset.AutoSize = $true
$form.Controls.Add($lblPreset)

$cmbPreset = New-Object System.Windows.Forms.ComboBox
$cmbPreset.DropDownStyle = 'DropDownList'
$cmbPreset.Location = New-Object System.Drawing.Point(210, 59)
$cmbPreset.Size = New-Object System.Drawing.Size(100, 28)
[void]$cmbPreset.Items.AddRange($presets)
$cmbPreset.SelectedIndex = 0
$form.Controls.Add($cmbPreset)

$lblVideo = New-Object System.Windows.Forms.Label
$lblVideo.Text = '画面预设：'
$lblVideo.Location = New-Object System.Drawing.Point(325, 63)
$lblVideo.AutoSize = $true
$form.Controls.Add($lblVideo)

$cmbVideo = New-Object System.Windows.Forms.ComboBox
$cmbVideo.DropDownStyle = 'DropDownList'
$cmbVideo.Location = New-Object System.Drawing.Point(400, 59)
$cmbVideo.Size = New-Object System.Drawing.Size(200, 28)
[void]$cmbVideo.Items.AddRange($videoPresets)
$cmbVideo.SelectedIndex = 0
$form.Controls.Add($cmbVideo)

$btnPlay = New-Object System.Windows.Forms.Button
$btnPlay.Text = '一键播放'
$btnPlay.Location = New-Object System.Drawing.Point(620, 55)
$btnPlay.Size = New-Object System.Drawing.Size(100, 32)
$form.Controls.Add($btnPlay)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = '复制推荐'
$btnCopy.Location = New-Object System.Drawing.Point(730, 55)
$btnCopy.Size = New-Object System.Drawing.Size(95, 32)
$form.Controls.Add($btnCopy)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = '选择视频，或把文件拖进窗口。'
$lblStatus.Location = New-Object System.Drawing.Point(15, 98)
$lblStatus.Size = New-Object System.Drawing.Size(860, 24)
$lblStatus.Anchor = 'Top,Left,Right'
$form.Controls.Add($lblStatus)

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Multiline = $true
$txtOut.ReadOnly = $true
$txtOut.ScrollBars = 'Vertical'
$txtOut.Location = New-Object System.Drawing.Point(15, 130)
$txtOut.Size = New-Object System.Drawing.Size(870, 495)
$txtOut.Anchor = 'Top,Bottom,Left,Right'
$txtOut.Font = New-Object System.Drawing.Font('Consolas', 10)
$form.Controls.Add($txtOut)

function Get-FileInfo([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "文件不存在：$path" }
    $json = & $ffprobe -v quiet -print_format json -show_format -show_streams -- $path 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'ffprobe 解析失败' }
    return ($json | ConvertFrom-Json)
}

function Format-Info($data) {
    $v = $data.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
    $a = $data.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('文件：' + $data.format.filename)
    $lines.Add('容器：' + $data.format.format_name + '  时长：' + [math]::Round([double]$data.format.duration, 1) + ' 秒')
    if ($v) {
        $hdr = 'SDR'
        if ($v.color_transfer -eq 'smpte2084') { $hdr = 'HDR10 / PQ' }
        elseif ($v.color_transfer -eq 'arib-std-b67') { $hdr = 'HLG' }
        $dv = $false
        if ($v.side_data_list) { foreach ($sd in $v.side_data_list) { if ($sd.side_data_type -match 'DOVI|Dolby Vision') { $dv = $true } } }
        if ($dv) { $hdr = 'Dolby Vision' }
        $bit = if ($v.bits_per_raw_sample) { $v.bits_per_raw_sample } elseif ($v.pix_fmt -match '10') { '10' } else { '8' }
        $lines.Add(('视频：{0}x{1}  {2}  {3}bit  {4} fps  {5}' -f $v.width,$v.height,$hdr,$bit,$v.avg_frame_rate,$v.codec_name))
    } else { $lines.Add('视频：无视频流') }
    if ($a) {
        $layout = if ($a.channel_layout) { $a.channel_layout } else { '' }
        $lines.Add(('音频：{0}  {1} 声道  {2} Hz  {3}  {4}' -f $a.codec_name,$a.channels,$a.sample_rate,$layout,$a.bit_rate))
    } else { $lines.Add('音频：无音频流') }
    return $lines
}

function Get-Recommend($data) {
    $a = $data.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
    $v = $data.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('')
    $lines.Add('===== 推荐 =====')
    if ($a) {
        $ch = [int]$a.channels
        $codec = $a.codec_name
        if ($codec -match 'truehd|dts' -and $ch -ge 6) {
            $lines.Add('音频：DTS/TrueHD 多声道，优先 7.1.2；OXS 可上混，耳机建议 2.0。')
        } elseif ($ch -ge 6) {
            $lines.Add('音频：5.1/7.1 片源，OXS 选 7.1.2；5.1 音箱可选 5.1。')
        } elseif ($ch -eq 2) {
            $lines.Add('音频：立体声，耳机/普通音箱选 2.0；OXS 可上混 7.1.2。')
        } else {
            $lines.Add('音频：单声道/异常声道，建议 2.0。')
        }
    }
    if ($v) {
        $hdr = $v.color_transfer -in @('smpte2084','arib-std-b67')
        $dv = $false
        if ($v.side_data_list) { foreach ($sd in $v.side_data_list) { if ($sd.side_data_type -match 'DOVI|Dolby Vision') { $dv = $true } } }
        if ($dv) {
            $lines.Add('视频：Dolby Vision。madVR 不支持 DV 动态元数据，建议 MPC-VR/支持 DV 的播放器。')
        } elseif ($hdr) {
            $lines.Add('视频：HDR。建议 MPC-VR 10bit，或 madVR HDR；全屏独占验证 10bit。')
        } elseif ([int]$v.width -le 1280) {
            $lines.Add(('视频：{0}x{1} 低分辨率/SDR。建议 madVR 老片档，NGU Sharp。' -f $v.width,$v.height))
        } elseif ([int]$v.width -le 1920) {
            $lines.Add(('视频：{0}x{1} 1080p/SDR。建议 madVR 电影档，NGU Sharp。' -f $v.width,$v.height))
        } else {
            $lines.Add(('视频：{0}x{1} 4K/SDR。建议 madVR 电影档，图像放大基本不参与。' -f $v.width,$v.height))
        }
    }
    $lines.Add('音频预设按钮在左上角，可按外设手动改。')
    return $lines
}

$script:LastReport = ''
$script:LastData = $null
function Analyze {
    try {
        $path = $txtPath.Text.Trim('"')
        if (-not $path) { throw '请先选择视频文件' }
        $lblStatus.Text = '正在检测...'
        $form.Refresh()
        $data = Get-FileInfo $path
        $script:LastData = $data
        $lines = @(Format-Info $data) + @(Get-Recommend $data)
        $script:LastReport = ($lines -join "`r`n")
        $txtOut.Text = $script:LastReport
        $lblStatus.Text = '检测完成。选择音频/画面预设后可直接播放。'
        $a = $data.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1
        if ($a -and [int]$a.channels -le 2) { $cmbPreset.SelectedItem = '2.0' }
        elseif ($a -and [int]$a.channels -ge 6) { $cmbPreset.SelectedItem = '7.1.2' }
        $v = $data.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
        $autoVideo = 1
        if ($v) {
            $isHdr = $v.color_transfer -in @('smpte2084','arib-std-b67')
            $dv = $false
            if ($v.side_data_list) { foreach ($sd in $v.side_data_list) { if ($sd.side_data_type -match 'DOVI|Dolby Vision') { $dv = $true } } }
            if ($isHdr -or $dv) { $autoVideo = 3 }
            elseif ([int]$v.width -le 1280) { $autoVideo = 2 }
        }
        $cmbVideo.SelectedIndex = 0
    } catch {
        $lblStatus.Text = '检测失败'
        $txtOut.Text = $_.Exception.Message + "`r`nLine=" + $_.InvocationInfo.ScriptLineNumber
    }
}

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = '视频文件|*.mkv;*.mp4;*.m2ts;*.ts;*.avi;*.mov;*.wmv;*.flv|所有文件|*.*'
    if ($dlg.ShowDialog() -eq 'OK') { $txtPath.Text = $dlg.FileName; Analyze }
})
$btnAnalyze.Add_Click({ Analyze })
$btnPlay.Add_Click({
    try {
        $path = $txtPath.Text.Trim('"')
        if (-not (Test-Path -LiteralPath $path)) { throw '文件不存在' }
        if (-not (Test-Path -LiteralPath $pot)) { throw '找不到 PotPlayer' }
        $audioPreset = [string]$cmbPreset.SelectedItem
        $videoPreset = [string]$cmbVideo.SelectedItem
        if ($videoPreset -ne '跟随 PotPlayer 预设（推荐）') {
            if ($videoPreset -eq '自动（按片源）') {
                $v = $script:LastData.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1
                $isHdr = $v -and ($v.color_transfer -in @('smpte2084','arib-std-b67'))
                if ($isHdr) { $videoPreset = 'MPC-VR 10bit HDR' }
                elseif ($v -and [int]$v.width -le 1280) { $videoPreset = 'madVR 老片 1080p' }
                else { $videoPreset = 'madVR 电影 SDR' }
            }
            Get-Process -Name 'PotPlayerMini64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 800
            if ($videoPreset -like 'MPC-VR*') {
                Set-ItemProperty -Path 'HKCU:\Software\DAUM\PotPlayerMini64' -Name 'VideoRen2' -Value 16 -Type DWord
            } else {
                $madvrProfile = if ($videoPreset -like '*老片*') { 'old-film' } else { 'movie' }
                if (-not $madvrScript) { throw '未配置 madVRProfileScript，无法切换 madVR 画面预设' }; & $madvrScript -ProfileName $madvrProfile -NoLaunch | Out-Null
                Start-Sleep -Milliseconds 500
                Set-ItemProperty -Path 'HKCU:\Software\DAUM\PotPlayerMini64' -Name 'VideoRen2' -Value 10 -Type DWord
            }
        }
        $argLine = '"' + $path + '" /new config="' + $audioPreset + '"'
        Start-Process -FilePath $pot -ArgumentList $argLine
        $lblStatus.Text = "已启动：音频 $audioPreset / 画面 $videoPreset"
    } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message) | Out-Null }
})
$btnCopy.Add_Click({
    if ($script:LastReport) { [System.Windows.Forms.Clipboard]::SetText($script:LastReport); $lblStatus.Text = '推荐已复制' }
})
$form.Add_DragEnter({
    if ($_.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $_.Effect = 'Copy' }
})
$form.Add_DragDrop({
    $files = $_.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    if ($files -and $files.Count -gt 0) { $txtPath.Text = $files[0]; Analyze }
})
if ($FilePath) { $txtPath.Text = $FilePath; Analyze }
[void]$form.ShowDialog()
