#!/usr/bin/env bash
# Lab driver: real bin/fm-remote-doctor.sh from the run worktree, driven against
# the test suite's own disposable account fixture (private HOME, fake launchctl,
# fake herdr, fake dscl/lsof). Nothing here touches the operator's LaunchAgents.
LAB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
. "$LAB/prelude.sh"
set +e
EV=/Users/duncancrawford/.no-mistakes/evidence/01M3W36T12XSSDT56XTBTAJBGB
BASE_DOCTOR=/var/folders/3r/93wyl1w9045gms3gx1zwqwsh0000gn/T//fm-doctor-base.4WvYiG/bin/fm-remote-doctor.sh
TARGET_DOCTOR="$ROOT/bin/fm-remote-doctor.sh"
RESULTS="$EV/lab-results.txt"; : > "$RESULTS"
FAILS=0
check() { # <scenario> <description> <cond...>
  local sc=$1 desc=$2; shift 2
  if "$@"; then printf 'PASS %s: %s\n' "$sc" "$desc" | tee -a "$RESULTS"
  else printf 'FAIL %s: %s\n' "$sc" "$desc" | tee -a "$RESULTS"; FAILS=$((FAILS+1)); fi
}
has() { case "$1" in *"$2"*) return 0;; esac; return 1; }
lacks() { ! has "$1" "$2"; }
log_lacks() { ! grep -q -E "$2" "$1" 2>/dev/null; }
log_has() { grep -q -E "$2" "$1" 2>/dev/null; }
SKIP='skip: this run did not come through the fixed remote entrypoint'
SIX=(remote-job-worker remote-job-worker-loaded remote-job-probe launchagent launchagent-scope launchagent-loaded)

# doctor_env <script> [env assignments...] -- [doctor args]
# Same fixture environment as the suite's doctor(), but the caller owns
# FM_ROOT_OVERRIDE and FM_REMOTE_JOB_ACTIVE instead of the helper defaulting them.
doctor_env() {
  local script=$1; shift
  local extra=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do extra+=("$1"); shift; done
  [ $# -eq 0 ] || shift
  DOCTOR_OUT=$(
    env -u FM_ROOT_OVERRIDE -u FM_REMOTE_JOB_ACTIVE \
    HOME="$CASE_HOME" FM_HOME="$CASE_PROJECT_HOME" \
    PATH="$CASE_HOME/.local/bin:$CASE_BIN:$BASE_PATH" \
    FM_FAKE_STATE="$CASE_STATE" FM_FAKE_LAUNCHCTL_LOG="$CASE_LAUNCHCTL_LOG" \
    FM_FAKE_FORBIDDEN_LOG="$CASE_FORBIDDEN_LOG" FM_FAKE_HERDR_RUNNING="$CASE_HERDR_RUNNING" \
    FM_FAKE_HERDR_BIN="$CASE_BIN/herdr" FM_FAKE_HERDR_SOCKET="$CASE_STATE/herdr.sock" \
    FM_FAKE_GUARD="$GUARD" FM_FAKE_AQUA_PID="$AQUA_HOLDER_PID" \
    FM_FAKE_PLIST="$CASE_PLIST" FM_FAKE_JOB_PLIST="$CASE_JOB_PLIST" \
    FM_FAKE_JOB_WORKER="$ROOT/bin/fm-remote-job-worker.sh" \
    FM_FAKE_LAUNCH_AGENT_LOG="$CASE_HOME/Library/Logs/$LABEL.log" \
    FM_FAKE_LOGIN_SHELL="${CASE_LOGIN_SHELL:-/bin/sh}" FM_FAKE_DSCL_FAIL=0 FM_FAKE_DSCL_HANG=0 \
    FM_LAUNCH_AGENT_SHELL="$CASE_LOGIN_SHELL" SHELL="${SHELL-}" \
    FM_REMOTE_JOB_PLATFORM_OVERRIDE="${CASE_PLATFORM_OVERRIDE-}" \
    "${extra[@]}" "$script" "$@" 2>&1)
  DOCTOR_RC=$?
}
save() { # <name>
  printf '%s\n' "$DOCTOR_OUT" > "$EV/$1.transcript.txt"
  printf 'exit=%s\n' "$DOCTOR_RC" >> "$EV/$1.transcript.txt"
  { echo "# launchctl calls seen by the fixture"; cat "$CASE_LAUNCHCTL_LOG"; echo; echo "# \$HOME/Library/LaunchAgents"; ls -la "$CASE_HOME/Library/LaunchAgents" 2>&1; } > "$EV/$1.launchctl-and-plists.txt"
}
expect_six_skips() { # <scenario>
  local n
  for n in "${SIX[@]}"; do check "$1" "reports check $n=$SKIP" has "$DOCTOR_OUT" "check $n=$SKIP"; done
}
expect_nothing_installed() { # <scenario>
  check "$1" "no fix launchagent=applied line" lacks "$DOCTOR_OUT" 'fix launchagent='
  check "$1" "no fix remote-job-worker=applied line" lacks "$DOCTOR_OUT" 'fix remote-job-worker='
  check "$1" "no fixable/action lines for launchagent or remote-job-worker" lacks "$DOCTOR_OUT" 'action: launchagent'
  check "$1" "no action: remote-job-worker line" lacks "$DOCTOR_OUT" 'action: remote-job-worker'
  check "$1" "Herdr agent plist absent in HOME" test ! -e "$CASE_PLIST"
  check "$1" "remote-job plist absent in HOME" test ! -e "$CASE_JOB_PLIST"
  check "$1" "launchctl never asked to bootout/bootstrap/kickstart" log_lacks "$CASE_LAUNCHCTL_LOG" '^(bootout|bootstrap|kickstart)'
  check "$1" "no auto-login/FileVault/keychain tool reached" test ! -s "$CASE_FORBIDDEN_LOG"
}

# S1: local run on the captain's own macOS, GUI session present, herdr present, --fix
new_case Darwin with-herdr gui
doctor_env "$TARGET_DOCTOR" -- --fix; save s1-local-darwin-fix
check S1 "doctor prints entrypoint=no" has "$DOCTOR_OUT" 'entrypoint=no'
check S1 "gui-session=ok (a GUI session exists, so the old code would have installed)" has "$DOCTOR_OUT" 'check gui-session=ok:'
expect_six_skips S1
expect_nothing_installed S1
check S1 "entrypoint-link reports the same skip reason" has "$DOCTOR_OUT" "check entrypoint-link=$SKIP"
check S1 "report keeps its shape: 10 check lines" test "$(printf '%s\n' "$DOCTOR_OUT" | grep -c '^check ')" = 10

# S1b: same host, read-only run (no --fix)
new_case Darwin with-herdr gui
doctor_env "$TARGET_DOCTOR" --; save s1b-local-darwin-check
expect_six_skips S1b
expect_nothing_installed S1b

# S2 (adversarial): FM_ROOT_OVERRIDE exported but empty is still a local run
new_case Darwin with-herdr gui
doctor_env "$TARGET_DOCTOR" FM_ROOT_OVERRIDE= -- --fix; save s2-empty-marker-fix
check S2 "doctor prints entrypoint=no with an empty marker" has "$DOCTOR_OUT" 'entrypoint=no'
expect_six_skips S2
expect_nothing_installed S2

# S3: genuine remote path (marker set as fm-on.sh's entrypoint does) still installs both agents
new_case Darwin with-herdr gui
doctor_env "$TARGET_DOCTOR" FM_ROOT_OVERRIDE="$ROOT" -- --fix; save s3-remote-path-fix
check S3 "fix launchagent=applied" has "$DOCTOR_OUT" 'fix launchagent=applied:'
check S3 "remote-job-worker repair attempted (fix line present; the fixture has no real worker to heartbeat)" has "$DOCTOR_OUT" 'fix remote-job-worker='
check S3 "check launchagent=ok after repair" has "$DOCTOR_OUT" 'check launchagent=ok:'
check S3 "check launchagent-scope=ok Aqua" has "$DOCTOR_OUT" 'check launchagent-scope=ok: LimitLoadToSessionType=Aqua'
check S3 "check remote-job-worker=ok after repair" has "$DOCTOR_OUT" 'check remote-job-worker=ok:'
check S3 "check remote-job-worker-loaded=ok" has "$DOCTOR_OUT" 'check remote-job-worker-loaded=ok:'
check S3 "no skip lines on the remote path" lacks "$DOCTOR_OUT" "$SKIP"
check S3 "Herdr agent plist written" test -f "$CASE_PLIST"
check S3 "remote-job plist written" test -f "$CASE_JOB_PLIST"
check S3 "launchctl bootstrapped the Herdr agent" log_has "$CASE_LAUNCHCTL_LOG" "^bootstrap gui/$(id -u) .*dev.firstmate.herdr.fm-remote.plist"
check S3 "launchctl bootstrapped the remote-job worker" log_has "$CASE_LAUNCHCTL_LOG" "^bootstrap gui/$(id -u) .*dev.firstmate.remote-job.plist"
plist_ok() { # <plist> <herdr-bin>: parse the owned plist and check its meaning
  python3 - "$1" "$2" "$GUARD" <<'PYC'
import plistlib,sys
d=plistlib.load(open(sys.argv[1],"rb"))
ok = d["Label"]=="dev.firstmate.herdr.fm-remote" and d["LimitLoadToSessionType"]=="Aqua" \
  and d["RunAtLoad"] is True and d["KeepAlive"]=={"SuccessfulExit":False} \
  and d["ProgramArguments"][1:3]==["-l","-c"] \
  and d["ProgramArguments"][3]=="exec '%s' '%s' 'fm-remote'"%(sys.argv[3],sys.argv[2])
sys.exit(0 if ok else 1)
PYC
}
check S3 "herdr agent plist parses with the owned contract" plist_ok "$CASE_PLIST" "$CASE_BIN/herdr"

# S4: regression repro - the BASE doctor on the identical local run installs both agents
new_case Darwin with-herdr gui
doctor_env "$BASE_DOCTOR" -- --fix; save s4-base-local-darwin-fix
check S4-base "base doctor reports fix launchagent=applied on a local run (the bug)" has "$DOCTOR_OUT" 'fix launchagent=applied:'
check S4-base "base doctor attempts the remote-job-worker install on a local run (the bug)" has "$DOCTOR_OUT" 'fix remote-job-worker='
check S4-base "base doctor wrote the Herdr agent plist locally" test -f "$CASE_PLIST"
check S4-base "base doctor wrote the remote-job plist locally" test -f "$CASE_JOB_PLIST"
check S4-base "base doctor bootstrapped into gui/<uid>" log_has "$CASE_LAUNCHCTL_LOG" '^bootstrap gui/'

# S5: local run on Linux (no LaunchAgents, but the Linux worker start is gated too)
new_case Linux with-herdr no-gui
doctor_env "$TARGET_DOCTOR" -- --fix; save s5-local-linux-fix
check S5 "platform=linux" has "$DOCTOR_OUT" 'platform=linux'
check S5 "remote-job-worker skipped" has "$DOCTOR_OUT" "check remote-job-worker=$SKIP"
check S5 "remote-job-probe skipped" has "$DOCTOR_OUT" "check remote-job-probe=$SKIP"
check S5 "no fix remote-job-worker line" lacks "$DOCTOR_OUT" 'fix remote-job-worker='
check S5 "no Linux worker state created under HOME" test ! -e "$CASE_HOME/.firstmate/remote-job/worker.pid"
check S5 "launchctl never invoked" test ! -s "$CASE_LAUNCHCTL_LOG"
check S5 "herdr server still started locally (declined finding, decided behaviour)" has "$DOCTOR_OUT" 'fix herdr-server=applied:'

# S6: real /bin/launchctl GUI session, mutation-refusing shim, real uname/dscl, isolated HOME
new_case Darwin with-herdr gui
rm -f "$CASE_BIN/launchctl" "$CASE_BIN/uname" "$CASE_BIN/dscl" "$CASE_BIN/lsof" "$CASE_BIN/sleep"
cat > "$CASE_BIN/launchctl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_FAKE_LAUNCHCTL_LOG"
case "${1:-}" in
  print) exec /bin/launchctl "$@" ;;
  *) printf 'REFUSED by lab shim: launchctl %s\n' "$*" >&2; exit 97 ;;
esac
SH
chmod +x "$CASE_BIN/launchctl"
doctor_env "$TARGET_DOCTOR" FM_LAUNCH_AGENT_SHELL= -- --fix; save s6-real-launchctl-local-fix
check S6 "real launchctl reports gui/$(id -u) session ok" has "$DOCTOR_OUT" "check gui-session=ok: gui/$(id -u)"
check S6 "real Directory Services login shell resolved (no FM_LAUNCH_AGENT_SHELL pin)" test -z "$(cat "$CASE_STATE/dscl-count" 2>/dev/null)"
expect_six_skips S6
expect_nothing_installed S6
check S6 "shim saw only print calls" test "$(grep -v -c '^print ' "$CASE_LAUNCHCTL_LOG")" = 0
check S6 "no REFUSED attempts in transcript" lacks "$DOCTOR_OUT" 'REFUSED by lab shim'
cp "$CASE_LAUNCHCTL_LOG" "$EV/s6-real-launchctl-shim-calls.txt"

echo "=== FAILS=$FAILS ==="
printf 'FAILS=%s\n' "$FAILS" >> "$RESULTS"
exit "$FAILS"
