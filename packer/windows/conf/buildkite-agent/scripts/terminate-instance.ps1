$Token = (Invoke-WebRequest -UseBasicParsing -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

Write-Output "terminate-instance: requesting instance termination..."
aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--should-decrement-desired-capacity" 2> $null

if ($lastexitcode -eq 0) { # If autoscaling request was successful, we will terminate
  Write-Output "terminate-instance: disabling buildkite-agent service"
  nssm stop buildkite-agent
} else {
  Write-Output "terminate-instance: ASG could not decrement (we're already at minSize)"
  if ($Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB -eq "true") {
    Write-Output "terminate-instance: marking instance as unhealthy"
    aws autoscaling set-instance-health `
      --instance-id "$InstanceId" `
      --region "$Region" `
      --health-status Unhealthy `
      --no-should-respect-grace-period
  }
}
