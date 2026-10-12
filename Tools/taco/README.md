# Tabela de alimentos (TACO)

`MacroFit/Resources/taco.json` é gerado por `generate_taco.py` a partir dos CSVs em `source/`.

- **Fonte:** TACO — Tabela Brasileira de Composição de Alimentos, 4ª edição revisada e ampliada.
  NEPA/UNICAMP, Campinas, 2011. A reprodução é permitida desde que a fonte seja citada.
- **CSVs:** do projeto [raulfdm/taco-api](https://github.com/raulfdm/taco-api) (licença MIT), que normalizou a
  planilha original `Taco_4a_edicao_2011.xls`.
- **Conferência:** os 596 alimentos (kcal, proteína, lipídeos e carboidrato) foram comparados com a planilha original
  e não há diferença além do arredondamento.
- **Excluídos:** alimentos sem calorias na TACO (marcados como "em reanálise" ou "não se aplica"): leite integral,
  leite desnatado UHT, iogurte sabor abacaxi, coco verde, sal grosso e sal dietético. Cadastre-os em "Meus alimentos"
  pelo rótulo.

Para regerar: `python3 Tools/taco/generate_taco.py`
