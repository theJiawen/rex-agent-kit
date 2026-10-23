#!/usr/bin/env bash
# Opens a Rex session named "demo" with stand-in agents (demo/agent.sh), to record Agent Wall without showing your
# own work. It shows the session in the Rex app, hides the sidebar and makes the text bigger.
#   demo/start.sh [N]      open the demo with N agents (2–6, default 6)
#   demo/start.sh --stop   close it and put the app back the way it was
#   demo/start.sh sidebar  toggle the sidebar (if it came out the wrong way round)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
tasks=(auth-refactor flaky-tests docs-pass search-perf soft-deletes dark-mode)
state=${XDG_STATE_HOME:-$HOME/.local/state}/rex-wall/demo.json
FONT_STEPS=2

app=$(rex client ls --json | jq -r 'first(.clients[] | select(.info.kind? == "app") | .client_id) // empty')
[ -n "$app" ] || { echo "Open the Rex app first." >&2; exit 1; }
ui() { rex -C "$app" do "$@" >/dev/null; }

case ${1:-} in
  sidebar)
    ui client.sidebar.toggle
    [ -f "$state" ] && jq '.toggles += 1' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
    exit 0 ;;
  --stop)
    [ -f "$state" ] || { echo "No demo running."; exit 0; }
    demo=$(jq -r .demo "$state") back=$(jq -r '.back // empty' "$state")
    [ -n "$back" ] && ui session.select session_id="$back"
    rex kill "$demo" >/dev/null 2>&1 || true
    for ((i = 0; i < FONT_STEPS; i++)); do ui client.font.decrease; done
    [ $(( $(jq -r '.toggles // 1' "$state") % 2 )) = 1 ] && ui client.sidebar.toggle
    rm -f "$state"
    echo "Demo closed."
    exit 0 ;;
esac

n=${1:-6}
[ "$n" -ge 2 ] && [ "$n" -le ${#tasks[@]} ] || { echo "N is 2–${#tasks[@]}." >&2; exit 2; }
[ -f "$state" ] && { echo "A demo is already open: demo/start.sh --stop first." >&2; exit 1; }

back=$(rex client ls --json | jq -r --arg c "$app" '.clients[] | select(.client_id == $c) | .session_ids[0] // empty')
demo=$(rex new demo --window "${tasks[0]}" --json -- "$here/agent.sh" "${tasks[0]}" | jq -r .session_id)
for t in "${tasks[@]:1:n-1}"; do
  rex window new -s "$demo" "$t" --focus=false --json -- "$here/agent.sh" "$t" >/dev/null
done
rex focus -s "$demo" 1 >/dev/null
mkdir -p "$(dirname "$state")"
jq -n --arg demo "$demo" --arg back "$back" '{demo: $demo, back: $back, toggles: 1}' >"$state"

ui session.select session_id="$demo"
ui client.sidebar.toggle
for ((i = 0; i < FONT_STEPS; i++)); do ui client.font.increase; done

cat <<EOF
Demo open: $n stand-in agents in the "demo" session.
  1. Cmd+Shift+5 → Record Selected Window → click the Rex window.
  2. Click a few tabs, then Cmd+Shift+A (the wall). Wait 3 seconds. Cmd+Shift+A again.
  3. Stop with ⏹ in the menu bar.
  4. demo/start.sh --stop
If the sidebar showed up instead of hiding: demo/start.sh sidebar
EOF
