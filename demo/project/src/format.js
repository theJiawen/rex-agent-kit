// Formats an amount in cents as dollars: 123456 → "$1,234.56".
export function formatPrice(cents) {
  const dollars = Math.floor(cents / 100);
  const rest = cents % 100;
  const withCommas = String(dollars).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return `$${withCommas}.${String(rest).padStart(2, "0")}`;
}
