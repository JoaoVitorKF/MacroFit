#!/usr/bin/env python3
"""
Gera MacroFit/Resources/taco.json a partir da TACO (Tabela Brasileira de Composição de Alimentos).

Fonte dos dados: TACO 4ª edição revisada e ampliada (NEPA/UNICAMP, Campinas, 2011).
Os CSVs em source/ vêm do projeto raulfdm/taco-api (licença MIT), que normalizou a planilha
original. Conferidos com a planilha original: 596 alimentos × (kcal, proteína, gordura,
carboidrato) sem nenhuma diferença além do arredondamento.

Regras:
- Valores por 100 g de parte comestível.
- Sem kcal ("*" = em reanálise pela TACO, ou "NA") → alimento excluído (não inventamos valores).
- Macro vazio ("NA" = não se aplica, ex.: proteína do azeite; "Tr" = traço) → 0.

Uso: python3 Tools/taco/generate_taco.py
"""
import csv
import json
import pathlib

here = pathlib.Path(__file__).resolve().parent
source = here / "source"
output = here.parent.parent / "MacroFit" / "Resources" / "taco.json"

categories = {row["id"]: row["name"] for row in csv.DictReader(open(source / "categories.csv", encoding="utf-8"))}
nutrients = {row["foodId"]: row for row in csv.DictReader(open(source / "nutrients.csv", encoding="utf-8"))}

def number(value: str) -> float:
    value = value.strip()
    return float(value) if value else 0.0

foods, excluded = [], []
for row in csv.DictReader(open(source / "food.csv", encoding="utf-8")):
    n = nutrients[row["id"]]
    name = " ".join(row["name"].split())  # normaliza espaços duplos (ex.: "Coco,  verde")
    if not n["kcal"].strip():
        excluded.append(name)
        continue
    foods.append({
        "id": int(row["id"]),
        "name": name,
        "category": categories[row["categoryId"]],
        "kcal": number(n["kcal"]),
        "protein": number(n["protein"]),
        "fat": number(n["lipids"]),
        "carbs": number(n["carbohydrates"]),
    })

# Um alimento por linha: o arquivo fica legível e os diffs no git ficam pequenos
lines = ",\n".join(json.dumps(food, ensure_ascii=False) for food in foods)
output.write_text("[\n" + lines + "\n]\n", encoding="utf-8")
print(f"{len(foods)} alimentos gravados em {output.relative_to(here.parent.parent)}")
print(f"{len(excluded)} excluídos por não terem calorias na TACO: {', '.join(excluded)}")
