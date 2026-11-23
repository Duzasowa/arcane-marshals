# Arcane Marshals — правила для Claude Code

Покрокова фентезі-стратегія в дусі HoMM5 на Godot 4.7 + GDScript. План — `PLAN.md` (ідемо крок за кроком, після кроку
ставимо `[x]`). Задум — `docs/CONCEPT.md`, екрани й системи — `docs/GAME_SKELETON.md`, формули — `docs/MECHANICS.md`,
відкриті питання — `docs/OPEN.md`, ассети й ліцензії — `assets/CREDITS.md`.
Документи пишемо українською, код і коментарі — англійською.

## Ассети HoMM5 — найважливіше правило
- Файли HoMM5 (іконки, портрети, звуки) — **лише приватні заглушки** у `D:\Games\h5_placeholders` (поза репо).
- **Ніколи** не копіювати їх у `res://`, не комітити, не класти в збірку, не показувати на публічних скріншотах.
- Гра бачить їх тільки через `PlaceholderAssets` (`Image.load_from_file` поза `res://`) за таблицею
  `data/placeholder_map.json`, а без теки показує нейтральну заміну.
- Моделі з HoMM5 не витягуємо й не використовуємо. 3D — KayKit / Quaternius (CC0) або свої.
- Заглушки **замінюються** своїми ассетами (не переробляються) у фазі Ф13.
- `docs/reference/H5_MECHANICS_REFERENCE.md` — опис механік для ідей і пропорцій. Таблиці й назви HoMM5 у гру не копіювати.

## Архітектура
- `game/data/` — класи ресурсів (`UnitDef`, `SpellDef`…), дані — у `data/**.tres`. Симуляція лише читає їх.
- `game/simulation/` — уся логіка гри. Тільки класи `RefCounted` з `class_name`, **без нод**, без `Engine`/`Time`/`OS`.
  Не читає нічого з `game/view/`, `game/ui/`, `game/ai/`.
- `game/view/` — 3D-показ. Лише **читає** стан і події симуляції (`BattleEvent`, `MapEvent`), ніколи не змінює стан.
- `game/ui/` — інтерфейс. Дії гравця перетворює на **команди** (`*Cmd`) і подає їх у симуляцію.
- `game/ai/` — ШІ, тобто «гравець без UI»: подає команди в ту саму чергу.
- `game/app/` — меню, сцени, налаштування, `PlaceholderAssets`.
- `tests/` — headless-тести, `scripts/` — заміри (`measure_*.gd`) і знімки (`screenshot*.gd`).

## Детермінізм (з першого дня)
- Стан змінюється тільки через команди: `apply(cmd)` спершу перевіряє, що команда допустима.
- У стані — цілі числа. Множники й відсотки — у проміле (1000 = ×1,0). Без `float` у правилах.
- Випадковість — тільки `SimRng` зі стану з відомим сідом. Ніякого `randi()`/`randf()`/`shuffle()`.
- Ітерація по `Dictionary` — у порядку вставки. Не залежати від `instance_id` чи адрес.
- Стан перевіряється `StateHasher.digest()`. Поля-кеші перелічити в `const HASH_SKIPPED_FIELDS: Array[StringName]`.
- Прогноз (черга ініціативи, прогноз удару) рахує та сама функція, що й симуляція, на копії стану або без змін стану.

## Стиль GDScript
- Статична типізація всюди: змінні, параметри, повернення, елементи масивів (`Array[int]`).
- Сітки — `PackedInt32Array`/`PackedByteArray`, індекс `x + y * width`.
- Пошук шляху в симуляції — свій A* або `AStarGrid2D`. `NavigationServer` у симуляції не використовувати.
- Нова здібність / заклинання / наказ = новий `.tres` + обробник. Ядро бою для цього не змінювати.

## Запуск
Godot: `D:\Programs\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe` (або `$env:GODOT_BIN`).
```powershell
$GODOT = "D:\Programs\Godot_v4.7.1-stable_win64\Godot_v4.7.1-stable_win64_console.exe"
& $GODOT --headless --path . --editor --quit          # імпорт і перевірка скриптів
& $GODOT --headless --path . -s tests/test_runner.gd   # усі тести
& $GODOT --headless --path . -s scripts/measure_<name>.gd  # заміри
& $GODOT --headless --path . --export-release "Windows Desktop" build/ArcaneMarshals.exe  # збірка
```
- Після зміни `.gd`/`.tscn`/`.tres`/`project.godot` — прогнати імпорт. Будь-який `ERROR:`/`SCRIPT ERROR:` означає «не готово».
- Новий `class_name` стає видимим іншим скриптам лише після імпорту (`--editor --quit`).
- Після зміни симуляції — прогнати тести.

## Тести
- Тест-раннер сам знаходить `tests/**/test_*.gd`. Кожен — клас `extends TestSuite` з методами `test_*()`, що
  викликають `expect_*`.
- Числові тести — з явним запасом від межі. Тести бою задають сід явно.

## Git
- Комітити лише за проханням користувача. Не комітити нічого з HoMM5 (тест-сторож `test_no_h5_assets_in_repo`).

## Пошук файлів
Тільки інструменти Grep/Glob. Ніяких `grep -r`, `find .`, `Get-ChildItem -Recurse` по корені проєкту.
