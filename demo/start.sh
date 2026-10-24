#!/usr/bin/env bash
# Opens a Rex session named "demo" to record Agent Wall without showing your own work: one Claude Code per tab, each in
# its own throwaway copy of demo/project under /tmp (permission prompts off, so none of them stops to ask). It shows the
# session in the Rex app, hides the sidebar and makes the text bigger. The Claudes get their tasks DEMO_DELAY seconds
# later (default 15), so you can start recording first and catch them starting.
#   demo/start.sh [N]               N Claudes (2–6, default 6), on Sonnet unless DEMO_MODEL says otherwise
#   demo/start.sh --stand-ins [N]   stand-in agents (demo/agent.sh) instead: no Claude, no usage
#   demo/start.sh --no-view ...     leave the app's view alone
#   demo/start.sh --stop            close it and put the app back the way it was
#   demo/start.sh sidebar           toggle the sidebar (if it came out the wrong way round)
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
state=${XDG_STATE_HOME:-$HOME/.local/state}/rex-wall/demo.json
root=/tmp/rex-demo
FONT_STEPS=2

names=(cart-bug search-perf soft-deletes api-docs format-tests code-review)
prompts=(
  "Cart totals are sometimes off by a cent. Find out why in src/cart.js, fix it, and add tests for rounding and discounts. Run the tests."
  "search() in src/search.js is slow on 10,000 products (sampleProducts()). Make it faster without changing its results, add tests for search, and show the timing before and after."
  "Add soft deletes to src/orders.js: deleteOrder marks the order deleted, listOrders hides deleted ones, restoreOrder brings one back. Add tests and run them."
  "Write docs/API.md documenting every exported function in src/, with a short example for each, and check that every example runs."
  "Add tests for formatPrice in src/format.js, including negative and very large amounts, fix what they catch, and run the tests."
  "Review src/ for bugs and slow spots. List the top 5 with file:line and a one-line fix for each. Don't edit any files."
)
stand_ins=(auth-refactor flaky-tests docs-pass search-perf soft-deletes dark-mode)

app=$(rex client ls --json | jq -r 'first(.clients[] | select(.info.kind? == "app") | .client_id) // empty')
ui() { [ -z "$app" ] || rex -C "$app" do "$@" >/dev/null 2>&1 || echo "(The app didn't take $1: do it by hand.)" >&2; }
has_view() { [ "$(jq -r 'if .view == false then "no" else "yes" end' "$state")" = yes ]; }

case ${1:-} in
  sidebar)
    ui client.sidebar.toggle
    [ -f "$state" ] && jq '.toggles += 1' "$state" >"$state.tmp" && mv "$state.tmp" "$state"
    exit 0 ;;
  --stop)
    [ -f "$state" ] || { echo "No demo running."; exit 0; }
    demo=$(jq -r .demo "$state") back=$(jq -r '.back // empty' "$state")
    if has_view; then
      [ -n "$back" ] && ui session.select session_id="$back"
      for ((i = 0; i < FONT_STEPS; i++)); do ui client.font.decrease; done
      [ $(( $(jq -r '.toggles // 1' "$state") % 2 )) = 1 ] && ui client.sidebar.toggle
    fi
    rex kill "$demo" >/dev/null 2>&1 || true
    rm -rf "$root" "$state"
    echo "Demo closed."
    exit 0 ;;
  --go)   # run in the background by a Claude demo: hand each Claude its task, a moment apart
    sleep "${DEMO_DELAY:-15}"
    demo=$(jq -r .demo "$state")
    rex session inspect "$demo" --json | jq -r '.windows[] | [.label, .layers[0].blocks[0].block_id] | @tsv' |
      while IFS=$'\t' read -r label b; do
        for ((i = 0; i < ${#names[@]}; i++)); do
          [ "${names[i]}" = "$label" ] || continue
          rex send -s "$demo" -b "$b" "${prompts[i]}" </dev/null && rex send-key -s "$demo" -b "$b" enter </dev/null
          sleep 1.5
        done
      done
    exit 0 ;;
esac

claude=1 view=1
while [ $# -gt 0 ]; do
  case $1 in
    --stand-ins) claude=0; shift ;;
    --no-view) view=0; shift ;;
    *) break ;;
  esac
done
n=${1:-6}
[ "$n" -ge 2 ] && [ "$n" -le ${#names[@]} ] || { echo "N is 2–${#names[@]}." >&2; exit 2; }
if [ -f "$state" ]; then
  if rex session inspect "$(jq -r .demo "$state")" --json >/dev/null 2>&1; then
    echo "A demo is already open: demo/start.sh --stop first." >&2
  else
    echo "The last demo was closed in the app: demo/start.sh --stop puts the text size and sidebar back, then start again." >&2
  fi
  exit 1
fi
[ $view = 1 ] && [ -z "$app" ] && { echo "Open the Rex app first (or pass --no-view)." >&2; exit 1; }
claude_bin=$(command -v claude || true)
[ $claude = 0 ] || [ -n "$claude_bin" ] || { echo "Claude Code (claude) isn't installed: try --stand-ins." >&2; exit 1; }

rm -rf "$root"
mkdir -p "$root"
for ((i = 0; i < n; i++)); do
  if [ $claude = 1 ]; then
    # Without Rex's variables a Claude doesn't know it's in Rex, so it won't rename the demo's session and tabs.
    label=${names[i]} dir=$root/$label
    cmd=(env -u REX_SESSION -u REX_BLOCK -u REX_SERVER "$claude_bin" --model "${DEMO_MODEL:-sonnet}" --dangerously-skip-permissions)
    cp -R "$here/project" "$dir"
  else
    label=${stand_ins[i]} dir=$root cmd=("$here/agent.sh" "$label")
  fi
  if [ $i = 0 ]; then
    demo=$(rex new demo --window "$label" -c "$dir" --json -- "${cmd[@]}" | jq -r .session_id)
  else
    rex window new -s "$demo" "$label" -c "$dir" --focus=false --json -- "${cmd[@]}" >/dev/null
  fi
done
rex focus -s "$demo" 1 >/dev/null
back=$(rex client ls --json | jq -r --arg c "$app" '.clients[] | select(.client_id == $c) | .session_ids[0] // empty')
mkdir -p "$(dirname "$state")"
jq -n --arg demo "$demo" --arg back "$back" --argjson view $([ $view = 1 ] && echo true || echo false) \
  '{demo: $demo, back: $back, view: $view, toggles: (if $view then 1 else 0 end)}' >"$state"

if [ $claude = 1 ]; then
  # A new folder makes Claude Code ask whether to trust it: say yes in each tab (they're copies of demo/project).
  blocks=($(rex session inspect "$demo" --json | jq -r '.windows[].layers[].blocks[].block_id'))
  waiting=${#blocks[@]}
  for ((t = 0; t < 30 && waiting > 0; t++)); do
    sleep 1
    for ((i = 0; i < ${#blocks[@]}; i++)); do
      b=${blocks[i]}
      [ "$b" = done ] && continue
      screen=$(rex capture -s "$demo" -b "$b" 2>/dev/null || true)
      if grep -q "trust this folder" <<<"$screen"; then
        rex send-key -s "$demo" -b "$b" down && rex send-key -s "$demo" -b "$b" enter
        blocks[i]=done waiting=$((waiting - 1))
      elif grep -q "Claude Code v" <<<"$screen"; then
        blocks[i]=done waiting=$((waiting - 1))
      fi
    done
  done
  nohup "$here/start.sh" --go >/dev/null 2>&1 &
fi

if [ $view = 1 ]; then
  ui session.select session_id="$demo"
  ui client.sidebar.toggle
  for ((i = 0; i < FONT_STEPS; i++)); do ui client.font.increase; done
fi

if [ $claude = 1 ]; then
  echo "Demo open: $n Claudes in the \"demo\" session. They get their tasks in ${DEMO_DELAY:-15} seconds."
else
  echo "Demo open: $n stand-in agents in the \"demo\" session."
fi
cat <<EOF
  1. Cmd+Shift+5 → Record Selected Window → click the Rex window.
  2. Click a few tabs, then Cmd+Shift+A (the wall). Wait a few seconds. Cmd+Shift+A again.
  3. Stop with ⏹ in the menu bar.
  4. demo/start.sh --stop
If the sidebar showed up instead of hiding: demo/start.sh sidebar
EOF
