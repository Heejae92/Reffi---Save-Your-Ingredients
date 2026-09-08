# Representative recipe content, 2026-09-07

Fridge inventory is Reffi's core service. Recipes help users decide how to use that stock. All content remains in `Reffi/Resources/recipes-seed.json`; Swift views contain no recipe content literals.

Fourteen recipes now have bilingual amounts for every ingredient: kimchi stew, doenjang stew, kimchi fried rice, egg fried rice, rolled omelette, bean sprout soup, braised tofu, stir-fried bok choy, tomato and egg stir-fry, tomato pasta, aglio e olio, scrambled eggs, French toast and grilled cheese. The amounts use each recipe's existing servings. Braised tofu now lists the cooking oil already required by its steps.

The existing kitchen-copy sheet shows amounts before the steps. Missing amounts remain compatible with old saved recipes. Amounts are cooking guidance, not an inventory sufficiency check or automatic consumption calculation. The user confirms leftover stock at completion. Recipe matching still matches ingredient identities and does not promise that the fridge contains a whole serving's quantities.

Seven recipes received fuller heat, timing and completion instructions. Tomato/egg stir-fry and French toast received explicit egg doneness checks. These are authored starting recipes; they have not been validated through a cooking trial. Remaining seed recipes do not yet have ingredient quantities.

Food-safety checks were compared with [USDA food safety basics](https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/food-safety-basics/steps-keep-food-safe) and [USDA egg guidance](https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/eggs/shell-eggs-farm-table). Reheated rice dishes specify 74°C / 165°F and the amended egg dishes specify 71°C / 160°F. Timing is an estimate and does not replace the stated doneness check.

YouTube remains an external search chosen by the user. Its button style and placement are unchanged. Search terms use the current app language; a built-in recipe name is resolved again before opening the search even if the cooking session began in the other language.
