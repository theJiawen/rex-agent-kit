// A cart holds lines of { price, qty }, with prices in dollars.
export function createCart() {
  return { lines: [], discountPercent: 0 };
}

export function addItem(cart, product, qty = 1) {
  const line = cart.lines.find((l) => l.id === product.id);
  if (line) line.qty += qty;
  else cart.lines.push({ id: product.id, name: product.name, price: product.price, qty });
  return cart;
}

export function removeItem(cart, productId) {
  cart.lines = cart.lines.filter((l) => l.id !== productId);
  return cart;
}

export function applyDiscount(cart, percent) {
  cart.discountPercent = percent;
  return cart;
}

export function subtotal(cart) {
  let sum = 0;
  for (const line of cart.lines) sum += line.price * line.qty;
  return sum;
}

// The total in dollars, after the discount and 13% tax.
export function total(cart) {
  const discounted = subtotal(cart) * (1 - cart.discountPercent / 100);
  const taxed = discounted * 1.13;
  return Math.floor(taxed * 100) / 100;
}
