/// Costo promedio ponderado nuevo al ingresar mercadería.
/// (stock viejo × costo viejo + cantidad × costo unitario) / stock total.
int weightedAverage({required int stockBefore, required int avgBefore, required int qtyAdded, required int unitCost}) {
  final total = stockBefore + qtyAdded;
  if (total <= 0) return 0;
  return ((stockBefore * avgBefore + qtyAdded * unitCost) / total).round();
}

/// Costo por unidad base a partir del precio de un pack/pote y cuántas unidades
/// base trae. Ej: pack de 6 aguas a Gs. 30.000 → 5.000 por unidad.
int perUnitCost({required int packCost, required int unitsPerPack}) {
  if (unitsPerPack <= 0) return 0;
  return (packCost / unitsPerPack).round();
}
