#!/usr/bin/env bash
# A stand-in agent for demo recordings: a made-up task on a made-up project, with steps that look busy.
# It never reads or changes anything. Usage: agent.sh TASK (one of the names in the case below).
set -u

task=${1:-auth-refactor}
case $task in
  auth-refactor) goal="Move session tokens into httpOnly cookies"
    files=(src/auth/session.ts src/auth/cookies.ts src/api/login.ts src/middleware/csrf.ts tests/auth.spec.ts)
    words=(setCookie sessionToken csrfToken localStorage) ;;
  flaky-tests) goal="Find why checkout.spec fails 1 run in 20"
    files=(tests/checkout.spec.ts src/cart/total.ts src/cart/store.ts tests/fixtures/cart.json src/clock.ts)
    words=(Date.now setTimeout await\ flush retry) ;;
  docs-pass) goal="Write the API reference for /v2/orders"
    files=(docs/api/orders.md src/api/orders.ts src/api/schema.ts docs/api/index.md examples/orders.http)
    words=(OrderStatus paginate cursor @deprecated) ;;
  search-perf) goal="Cut search p95 from 900 ms to 300 ms"
    files=(src/search/query.ts src/search/index.ts src/db/queries.sql bench/search.bench.ts src/cache/lru.ts)
    words=(ILIKE trigram LIMIT cacheKey) ;;
  soft-deletes) goal="Add soft deletes to the orders table"
    files=(migrations/0042_soft_delete.sql src/db/orders.ts src/api/orders.ts tests/orders.spec.ts src/db/scopes.ts)
    words=(deleted_at WHERE\ deleted_at withDeleted restore) ;;
  dark-mode) goal="Dark mode for the settings pages"
    files=(src/ui/theme.css src/ui/Settings.tsx src/ui/tokens.ts src/ui/Toggle.tsx tests/visual/settings.png)
    words=(--bg prefers-color-scheme data-theme contrast) ;;
  *) goal="Clean up $task"
    files=(src/index.ts src/utils.ts tests/index.spec.ts README.md)
    words=(TODO FIXME export import) ;;
esac

dim=$'\033[2m' bold=$'\033[1m' green=$'\033[32m' cyan=$'\033[36m' yellow=$'\033[33m' off=$'\033[0m'
frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
pick() { local a=("$@"); printf '%s' "${a[RANDOM % ${#a[@]}]}"; }
width() { echo $(( $(tput cols 2>/dev/null || echo 60) - 3 )); }
fit() { local w=$(width); [ ${#1} -gt $w ] && printf '%s…' "${1:0:w-1}" || printf '%s' "$1"; }

# Show TEXT with a spinner for a moment, then replace it with DONE and its colored DETAIL (dropped when the pane is
# too narrow for both). DETAIL_LEN is how wide DETAIL shows, without its color codes.
step() {
  local text=$1 done=$2 detail=${3:-} detail_len=${4:-0} n=$(( 8 + RANDOM % 25 )) i
  for ((i = 0; i < n; i++)); do
    printf '\r\033[K%s%s%s %s' "$cyan" "${frames[i % 10]}" "$off" "$(fit "$text")"
    sleep 0.08
  done
  [ $(( ${#done} + 1 + detail_len )) -gt "$(width)" ] && detail=""
  printf '\r\033[K%s●%s %s %s\n' "$green" "$off" "$(fit "$done")" "$detail"
}
tput civis 2>/dev/null
trap 'tput cnorm 2>/dev/null' EXIT

clear
printf '%s%s%s\n%s%s%s\n\n' "$bold" "$task" "$off" "$dim" "$(fit "$goal")" "$off"
printf '%s☐ Read the code it touches\n☐ Make the change\n☐ Tests green%s\n\n' "$dim" "$off"

passed=$(( 80 + RANDOM % 60 ))
while :; do
  f=$(pick "${files[@]}")
  case $(( RANDOM % 7 )) in
    0|1) d="($(( 40 + RANDOM % 400 )) lines)"; step "Reading $f" "Read $f" "$dim$d$off" ${#d} ;;
    2) w=$(pick "${words[@]}"); d="$(( 1 + RANDOM % 30 )) matches"
       step "Searching for $w" "Search \"$w\"" "$dim$d$off" ${#d} ;;
    3) a=$(( 2 + RANDOM % 40 )) r=$(( RANDOM % 15 )); d="+$a -$r"
       step "Editing $f" "Edit $f" "${green}+${a}${off} ${yellow}−${r}${off}" ${#d} ;;
    4) step "Thinking" "Plan: $(pick "check the edge cases" "keep the old path working" "split it in two" "test the slow case")" ;;
    5|6) passed=$(( passed + 1 + RANDOM % 4 )); d="in $(( 2 + RANDOM % 9 )).$(( RANDOM % 10 ))s"
       step "Running tests" "Tests: $passed passed" "$dim$d$off" ${#d} ;;
  esac
  sleep "0.$(( 2 + RANDOM % 7 ))"
done
