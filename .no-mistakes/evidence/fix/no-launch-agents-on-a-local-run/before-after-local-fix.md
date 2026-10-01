# Same disposable macOS account fixture (GUI session present, herdr present), run locally with no FM_ROOT_OVERRIDE: `fm-remote-doctor.sh --fix`

## BASE 8f756bb (before the fix)
fix remote-job-worker=failed: remote job worker did not report ready after startup
fix launchagent=applied: wrote the Aqua-scoped dev.firstmate.herdr.fm-remote launch agent running /private<base>/bin/fm-remote-herdr-guard.sh for <fixture>/bin/herdr via /bin/sh -l -c
fix launchagent-loaded=failed: the herdr server for session fm-remote did not come up inside the Aqua launch agent within 10s
check remote-job-worker=ok: <HOME>/Library/LaunchAgents/dev.firstmate.remote-job.plist matches the Firstmate-owned Aqua worker contract
check remote-job-worker-loaded=fixable: dev.firstmate.remote-job is not loaded in gui/501
check remote-job-probe=fixable: the remote job worker has not reported a fresh probe
check launchagent=ok: <HOME>/Library/LaunchAgents/dev.firstmate.herdr.fm-remote.plist matches the Firstmate-owned contract
check launchagent-scope=ok: LimitLoadToSessionType=Aqua
check launchagent-loaded=fixable: gui/501/dev.firstmate.herdr.fm-remote does not match the effective Firstmate-owned contract

launchctl bootout gui/501/dev.firstmate.remote-job
launchctl bootstrap gui/501 <HOME>/Library/LaunchAgents/dev.firstmate.remote-job.plist
launchctl kickstart -k gui/501/dev.firstmate.remote-job
launchctl bootout gui/501/dev.firstmate.remote-job
launchctl bootstrap gui/501 <HOME>/Library/LaunchAgents/dev.firstmate.remote-job.plist
launchctl kickstart -k gui/501/dev.firstmate.remote-job
launchctl bootout gui/501/dev.firstmate.herdr.fm-remote
launchctl bootstrap gui/501 <HOME>/Library/LaunchAgents/dev.firstmate.herdr.fm-remote.plist
launchctl kickstart -k gui/501/dev.firstmate.herdr.fm-remote

## TARGET 25297dd (after the fix)
fix herdr-server=applied: started the herdr server for session fm-remote
check remote-job-worker=skip: this run did not come through the fixed remote entrypoint
check remote-job-worker-loaded=skip: this run did not come through the fixed remote entrypoint
check remote-job-probe=skip: this run did not come through the fixed remote entrypoint
check launchagent=skip: this run did not come through the fixed remote entrypoint
check launchagent-scope=skip: this run did not come through the fixed remote entrypoint
check launchagent-loaded=skip: this run did not come through the fixed remote entrypoint

launchctl mutations: 0 ; plists in <HOME>/Library/LaunchAgents: 0
