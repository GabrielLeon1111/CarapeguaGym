import 'package:flutter/material.dart';

/// Ícono y color según la categoría (texto libre). Se elige por palabras clave;
/// las categorías nuevas caen en un estilo por defecto.
(IconData, Color) stockCategoryStyle(String category) {
  final c = category.toLowerCase();
  if (c.contains('prote')) return (Icons.icecream_rounded, const Color(0xFF2563EB));
  if (c.contains('pre') || c.contains('entreno')) return (Icons.bolt_rounded, const Color(0xFFEA580C));
  if (c.contains('bebida') || c.contains('agua') || c.contains('jugo')) return (Icons.local_drink_rounded, const Color(0xFF0891B2));
  if (c.contains('guante') || c.contains('accesorio') || c.contains('ropa')) return (Icons.sports_mma_rounded, const Color(0xFF7C3AED));
  if (c.contains('barra') || c.contains('snack') || c.contains('comida')) return (Icons.restaurant_rounded, const Color(0xFF16A34A));
  return (Icons.inventory_2_rounded, const Color(0xFF64748B));
}

/// Categorías sugeridas que siempre aparecen en el selector.
const defaultCategories = ['Proteína', 'Pre-entreno', 'Bebidas', 'Accesorios', 'Otro'];
