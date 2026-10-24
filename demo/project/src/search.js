// Finds products whose name or description has every word of the query, best matches first.
export function search(products, query) {
  const words = query.split(" ");
  const results = [];
  for (const product of products) {
    let score = 0;
    let all = true;
    for (const word of words) {
      const re = new RegExp(word.toLowerCase());
      const inName = re.test(product.name.toLowerCase());
      const inDescription = re.test(product.description.toLowerCase());
      if (!inName && !inDescription) all = false;
      if (inName) score += 2;
      if (inDescription) score += 1;
    }
    if (all) results.push({ product, score });
  }
  return results.sort((a, b) => b.score - a.score).map((r) => r.product);
}

// 10,000 made-up products, for timing search.
export function sampleProducts(n = 10000) {
  const kinds = ["lamp", "chair", "mug", "desk", "shelf", "rug", "kettle", "clock"];
  const colors = ["red", "oak", "black", "white", "green", "blue"];
  const products = [];
  for (let i = 0; i < n; i++) {
    const kind = kinds[i % kinds.length];
    const color = colors[(i * 7) % colors.length];
    products.push({ id: i, name: `${color} ${kind} ${i}`, description: `A ${color} ${kind} for your home.`, price: 5 + (i % 200) });
  }
  return products;
}
