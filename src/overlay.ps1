Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class QuotaPeekWindows {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
}
'@
$script:settings=Read-Settings
$script:zh=$script:settings.language -eq 'zh' -or ($script:settings.language -eq 'auto' -and [Globalization.CultureInfo]::CurrentUICulture.Name -like 'zh*')
function L([string]$zh,[string]$en){if($script:zh){return $zh}else{return $en}}
function Read-LocalJson($name){try{return Get-Content -LiteralPath (Join-Path $script:DataDirectory $name) -Raw -Encoding UTF8 | ConvertFrom-Json}catch{return $null}}
function Write-LocalJson($name,$value){
    $target=Join-Path $script:DataDirectory $name;$temp=$target+".$PID.tmp"
    $value|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $target -Force
}
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Codex Quota Peek" Width="350" Height="103" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" ShowActivated="False">
<Window.Resources><Style TargetType="ProgressBar"><Setter Property="Height" Value="6"/><Setter Property="Foreground" Value="#F3CD58"/><Setter Property="Background" Value="#39404B"/><Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ProgressBar"><Grid><Border Name="PART_Track" Background="{TemplateBinding Background}" CornerRadius="3"/><Border Name="PART_Indicator" HorizontalAlignment="Left" Background="{TemplateBinding Foreground}" CornerRadius="3"/></Grid></ControlTemplate></Setter.Value></Setter></Style></Window.Resources>
<Border Background="#ED20242C" CornerRadius="12" Padding="12,9" BorderBrush="#3D444F" BorderThickness="1"><Grid>
<Grid.ColumnDefinitions><ColumnDefinition Width="42"/><ColumnDefinition Width="*"/><ColumnDefinition Width="42"/><ColumnDefinition Width="17"/></Grid.ColumnDefinitions>
<Grid.RowDefinitions><RowDefinition Height="19"/><RowDefinition Height="19"/><RowDefinition Height="21"/><RowDefinition Height="18"/></Grid.RowDefinitions>
<TextBlock Name="ShortLabel" Text="5小时" Foreground="#B9C0CA" FontSize="11" VerticalAlignment="Center"/><ProgressBar Name="ShortBar" Grid.Column="1" Minimum="0" Maximum="100" VerticalAlignment="Center"/><TextBlock Name="ShortValue" Grid.Column="2" Foreground="#F3CD58" FontSize="12" HorizontalAlignment="Right" VerticalAlignment="Center"/>
<TextBlock Name="WeekLabel" Grid.Row="1" Text="本周" Foreground="#B9C0CA" FontSize="11" VerticalAlignment="Center"/><ProgressBar Name="WeekBar" Grid.Row="1" Grid.Column="1" VerticalAlignment="Center" Minimum="0" Maximum="100"/><TextBlock Name="WeekValue" Grid.Row="1" Grid.Column="2" Foreground="#F3CD58" FontSize="12" HorizontalAlignment="Right" VerticalAlignment="Center"/>
<Grid Name="WeekTrack" Grid.Row="1" Grid.Column="1" Height="6" VerticalAlignment="Center" IsHitTestVisible="False"><Border Name="TodaySegment" Background="#63ADFF" HorizontalAlignment="Left" CornerRadius="2" Width="0"/></Grid>
<TextBlock Name="Daily" Grid.Row="2" Grid.ColumnSpan="3" Foreground="#63ADFF" FontSize="11" VerticalAlignment="Center"/>
<TextBlock Name="Footer" Grid.Row="3" Grid.ColumnSpan="3" Foreground="#939CA9" FontSize="10" VerticalAlignment="Bottom" TextTrimming="CharacterEllipsis"/>
<Button Name="Close" Grid.Column="3" Grid.RowSpan="2" Content="×" Foreground="#77818F" Background="Transparent" BorderThickness="0" Padding="0" Margin="5,0,0,0" VerticalAlignment="Top"/>
</Grid></Border></Window>
'@
$script:window=[Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$work=[Windows.SystemParameters]::WorkArea
$window.Left=$work.Left+($work.Width-$window.Width)/2;$window.Top=$work.Top+8
if(!$script:IsDemo){
    $saved=Read-LocalJson 'window.json'
    if($saved -and $null -ne $saved.left -and $null -ne $saved.top){
        $valid=$false
        foreach($screen in [Windows.Forms.Screen]::AllScreens){$b=$screen.WorkingArea;if($saved.left -ge $b.Left -and $saved.left -lt $b.Right-60 -and $saved.top -ge $b.Top -and $saved.top -lt $b.Bottom-30){$valid=$true}}
        if($valid){$window.Left=$saved.left;$window.Top=$saved.top}
    }
}
$window.Add_MouseLeftButtonDown({if($_.OriginalSource -isnot [Windows.Controls.Button]){$window.DragMove();if(!$script:IsDemo){Write-LocalJson 'window.json' @{left=$window.Left;top=$window.Top}}}})
$window.FindName('Close').ToolTip=L '退出额度助手' 'Exit Quota Peek'
$window.FindName('Close').Add_Click({$window.Close()})
$window.FindName('WeekLabel').Text=L '本周' 'Week'
$script:snapshot=$null;$script:visible=$true;$script:lastSnapshot='';$script:lastSettingsCheck=[DateTime]::MinValue
function Render-Quota {
    if($script:collector -and $script:collector.HasExited -and ((Get-Date)-$script:collectorStarted).TotalSeconds -gt 30){Start-Collector}
    if(((Get-Date)-$script:lastSettingsCheck).TotalSeconds -ge 10){$script:settings=Read-Settings;$script:lastSettingsCheck=Get-Date}
    if($script:IsDemo){
        $script:snapshot=[pscustomobject]@{updatedAt=[DateTimeOffset]::Now.ToString('o');short=[pscustomobject]@{remaining=58;resetsAt=[DateTimeOffset]::Now.AddHours(3).ToString('o');minutes=300};week=[pscustomobject]@{remaining=66;resetsAt=[DateTimeOffset]::Now.AddDays(5).ToString('o')};daily=[pscustomobject]@{spent=6;segmentSpent=6;left=5.8;cap=11.8;segments=1;startedAt=[DateTimeOffset]::Now.AddHours(-2).ToString('o')}}
    }else{$incoming=Read-LocalJson 'snapshot.json';if($incoming){$script:snapshot=$incoming}}
    $s=$script:snapshot
    $health=if($script:IsDemo){$null}else{Read-LocalJson 'status.json'}
    if(!$s -or !$s.updatedAt){
        $window.FindName('ShortValue').Text='--';$window.FindName('WeekValue').Text='--';$window.FindName('ShortBar').Value=0;$window.FindName('WeekBar').Value=0;$window.FindName('TodaySegment').Width=0
        $window.FindName('Daily').Text=L '等待账户额度…' 'Waiting for account quota…'
        $window.FindName('Footer').Text=if($health.error){$health.error}else{L '正在连接 Codex' 'Connecting to Codex'}
        $window.ToolTip=L '请先安装并登录Codex。通过托盘菜单打开设置或查看状态。' 'Install and sign in to Codex. Open Settings or Status from the tray menu.'
        return
    }
    $age=([DateTimeOffset]::Now-[DateTimeOffset]::Parse($s.updatedAt)).TotalSeconds
    $stale=$age -gt [Math]::Max(45,2*[double]$script:settings.backgroundSeconds)
    $window.FindName('ShortBar').Value=if($s.short){$s.short.remaining}else{0}
    $window.FindName('WeekBar').Value=if($s.week){$s.week.remaining}else{0}
    $window.FindName('ShortValue').Text=if($s.short){'{0:0.#}%' -f $s.short.remaining}else{'--'}
    $window.FindName('WeekValue').Text=if($s.week){'{0:0.#}%' -f $s.week.remaining}else{'--'}
    $duration=if($s.short -and $s.short.minutes){[double]$s.short.minutes}else{0}
    $window.FindName('ShortLabel').Text=if($duration -eq 300){L '5小时' '5h'}elseif($duration -gt 0 -and $duration%60 -eq 0){'{0:0}h' -f ($duration/60)}else{L '短时' 'Short'}
    $window.FindName('ShortBar').Opacity=if($stale){0.4}else{1};$window.FindName('WeekBar').Opacity=if($stale){0.4}else{1}
    if($s.daily){
        $window.FindName('Daily').Text=if($script:zh){'今日已用周 {0:0.#}% · 还建议用周 {1:0.#}%' -f $s.daily.spent,$s.daily.left}else{'Today: {0:0.#}pp used · {1:0.#}pp suggested left' -f $s.daily.spent,$s.daily.left}
        $track=$window.FindName('WeekTrack').ActualWidth
        $window.FindName('TodaySegment').Margin=New-Object Windows.Thickness(($track*$s.week.remaining/100),0,0,0)
        $window.FindName('TodaySegment').Width=$track*[Math]::Min([double]$s.daily.segmentSpent,100-[double]$s.week.remaining)/100
    }else{$window.FindName('Daily').Text=L '本周建议暂不可用' 'Weekly budget unavailable';$window.FindName('TodaySegment').Width=0}
    $clock=[DateTimeOffset]::Parse($s.updatedAt).ToLocalTime().ToString('HH:mm:ss')
    $resetText=''
    if($s.short.resetsAt){$minutes=[Math]::Ceiling(([DateTimeOffset]::Parse($s.short.resetsAt)-[DateTimeOffset]::Now).TotalMinutes);if($minutes -gt 0){$resetText=if($script:zh){'{0}小时{1}分后重置' -f [Math]::Floor($minutes/60),($minutes%60)}else{'resets in {0}h {1}m' -f [Math]::Floor($minutes/60),($minutes%60)}}else{$resetText=L '等待重置数据' 'waiting for reset'}}
    $window.FindName('Footer').Text=if($script:IsDemo){L '示意数据 · 非真实账户' 'Demo data · not a real account'}elseif($health.error -or $stale){L "上次更新 $clock · 正在重试" "Last update $clock · retrying"}else{"$clock · $resetText"}
    $started=if($s.daily){[DateTimeOffset]::Parse($s.daily.startedAt).ToLocalTime().ToString('MM-dd HH:mm')}else{'--'}
    $weekReset=if($s.week.resetsAt){[DateTimeOffset]::Parse($s.week.resetsAt).ToLocalTime().ToString('MM-dd HH:mm')}else{'--'}
    $window.ToolTip=if($script:zh){"黄色=实际剩余；蓝色=本周期内今日已用。`n统计起点：$started；此前用量未计入。`n今日建议是规划值，不是官方限额；%指整周额度百分点。`n周重置：$weekReset；每日预算预留 $($script:settings.reservePercent)%。`n后台采集 $($script:settings.backgroundSeconds)秒，前台 $($script:settings.foregroundSeconds)秒。失败保留记录。`n同日重置前的消耗保留在今日数字中，蓝段只绘制新周期内消耗。"}else{"Yellow: actual remaining. Blue: today's usage in the current cycle.`nTracked since $started; earlier use is not counted. pp = percentage points of weekly quota.`nSuggested budget is a planning estimate, not an official daily limit.`nWeekly reset: $weekReset. Reserve: $($script:settings.reservePercent)%.`nForeground/background polling: $($script:settings.foregroundSeconds)/$($script:settings.backgroundSeconds)s. Stale values are preserved.`nDaily numbers include earlier same-day cycles; the blue segment shows only the current cycle."}
}
function Update-Visibility {
    if($script:IsDemo){return}
    try{
        [uint32]$foregroundId=0;[void][QuotaPeekWindows]::GetWindowThreadProcessId([QuotaPeekWindows]::GetForegroundWindow(),[ref]$foregroundId)
        $show=$false
        if($script:settings.showMode -eq 'always'){$show=$true}
        elseif($foregroundId -eq $PID){$show=$script:visible}
        elseif($foregroundId){$p=[Diagnostics.Process]::GetProcessById($foregroundId);$module=$p.MainModule;$show=($p.ProcessName -match '^(ChatGPT|Codex)$') -and ($module.FileVersionInfo.ProductName -eq 'Codex' -or $module.FileName -match '(?i)\\OpenAI\.Codex_|\\Codex\\')}
        if($show -ne $script:visible){$script:visible=[bool]$show;if($show){$window.Show()}else{$window.Hide()}}
        if($script:lastVisibility -ne [string]$show){Write-LocalJson 'visibility.json' @{visible=[bool]$show};$script:lastVisibility=[string]$show}
    }catch{if($script:visible){$window.Hide();$script:visible=$false};Write-LocalJson 'visibility.json' @{visible=$false}}
}
$tray=New-Object Windows.Forms.NotifyIcon
$tray.Icon=[Drawing.SystemIcons]::Information;$tray.Text='Codex Quota Peek'
$menu=New-Object Windows.Forms.ContextMenuStrip
$toggle=$menu.Items.Add((L '切换：仅Codex / 始终显示' 'Toggle: Codex only / always visible'))
$toggle.Add_Click({$script:settings=Read-Settings;$script:settings.showMode=if($script:settings.showMode -eq 'always'){'codex'}else{'always'};Save-Settings $script:settings;Update-Visibility})
$settingsItem=$menu.Items.Add((L '打开设置（JSON）' 'Open settings (JSON)'))
$settingsItem.Add_Click({Start-Process notepad.exe -ArgumentList ('"'+$script:ConfigPath+'"')})
$statusItem=$menu.Items.Add((L '打开连接状态' 'Open connection status'))
$statusItem.Add_Click({$statusFile=Join-Path $script:DataDirectory 'status.json';if(Test-Path $statusFile){Start-Process notepad.exe -ArgumentList ('"'+$statusFile+'"')}})
$exit=$menu.Items.Add((L '退出' 'Exit'));$exit.Add_Click({$window.Close()})
$tray.ContextMenuStrip=$menu;$tray.Visible=!$script:IsPreview
$renderTimer=New-Object Windows.Threading.DispatcherTimer;$renderTimer.Interval=[TimeSpan]::FromSeconds(1);$renderTimer.Add_Tick({try{Render-Quota}catch{$window.FindName('Footer').Text=L '读取失败，自动重试' 'Read failed; retrying'}});$renderTimer.Start()
$focusTimer=New-Object Windows.Threading.DispatcherTimer;$focusTimer.Interval=[TimeSpan]::FromMilliseconds(250);$focusTimer.Add_Tick({Update-Visibility});$focusTimer.Start()
$window.Add_Closed({$renderTimer.Stop();$focusTimer.Stop();$tray.Visible=$false;$tray.Dispose();$menu.Dispose()})
$window.Add_Loaded({Render-Quota;Update-Visibility})
Render-Quota
if($script:IsPreview){
    $window.Show();$window.UpdateLayout();Render-Quota
    $bitmap=New-Object Windows.Media.Imaging.RenderTargetBitmap(700,206,192,192,[Windows.Media.PixelFormats]::Pbgra32)
    $bitmap.Render($window.Content);$encoder=New-Object Windows.Media.Imaging.PngBitmapEncoder;$encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $stream=[IO.File]::Create([IO.Path]::GetFullPath($PreviewPath));try{$encoder.Save($stream)}finally{$stream.Dispose()};$window.Close()
}else{$app=New-Object Windows.Application;$app.ShutdownMode=[Windows.ShutdownMode]::OnMainWindowClose;$app.Run($window)|Out-Null}
