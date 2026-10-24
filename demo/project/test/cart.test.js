import { test } from "node:test";
import assert from "node:assert/strict";
import { createCart, addItem, removeItem, total } from "../src/cart.js";

test("total adds tax", () => {
  const cart = addItem(createCart(), { id: 1, name: "mug", price: 10 }, 2);
  assert.equal(total(cart), 22.6);
});

test("removeItem takes the line out", () => {
  const cart = addItem(addItem(createCart(), { id: 1, name: "mug", price: 10 }), { id: 2, name: "lamp", price: 30 });
  removeItem(cart, 1);
  assert.deepEqual(cart.lines.map((l) => l.id), [2]);
});
