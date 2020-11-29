$mma = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg'
if($mma.GetCloudWorkspace("YourWorkspaceIDHere")){
    Write-Host "Found Workspace"
}
else{
    Exit 1
}