// Orders kept in memory.
const orders = [];
let nextId = 1;

export function createOrder(customer, lines) {
  const order = { id: nextId++, customer, lines, createdAt: new Date() };
  orders.push(order);
  return order;
}

export function getOrder(id) {
  return orders.find((o) => o.id === id);
}

export function listOrders(customer) {
  return customer ? orders.filter((o) => o.customer === customer) : [...orders];
}

export function deleteOrder(id) {
  const i = orders.findIndex((o) => o.id === id);
  if (i >= 0) orders.splice(i, 1);
}
