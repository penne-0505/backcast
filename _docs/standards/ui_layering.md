# UI 階層化標準

## 目的

Medo の UI は、タイムライン編集画面を中心に、ヘッダー、floating commands、popover、sheet、modal、dialog が同じ画面上に重なります。
新しい UI を追加するときに重なり順や tap の扱いが揺れないよう、階層化の基準をここに定義します。

本標準では、UI 階層を見た目の高さだけでなく **入力イベントの所有権** として扱います。
上位 layer が表示されている間、下位 layer の action は直接実行せず、まず上位 layer の close / dismiss を優先します。
`Stack` の描画順はこの階層を反映しますが、同時表示禁止は各 open action でも明示的に守ります。

## Layer Model

### Layer 0: Timeline Canvas

タイムライン本体、block、rail、target anchor、empty state を置く主作業領域です。
通常の編集、選択、drag、reorder、rail 操作はこの layer に属します。

### Layer 1: Passive Visual Overlay

上下 fade、現在時刻 marker、検索ハイライトなど、視覚補助だけを担う layer です。
原則として `IgnorePointer` 相当で入力権を持たせません。

### Layer 2: Floating Commands

下部の追加 toolbar、timeline list button、density toggle など、タイムライン編集を補助する常設 command 群です。
作業上の主操作を含みますが、上位 layer が表示されている間は背面 layer として扱います。

### Layer 3: Header Panels

ヘッダー本体から開く検索 UI や export panel など、画面上部の補助操作です。
Timeline Canvas より上位にあり、Floating Commands より入力イベント上は上位として扱います。
Header Panels が開いている間に Floating Commands や Timeline Canvas を tap した場合、その tap はまず Header Panels の close に使います。

### Layer 4: Lightweight Popovers

template popover のように、scrim を置かず、現在の編集文脈へ補助操作を差し込む layer です。
外側 tap は popover を閉じるためだけに使い、背面の action は同時に発火させません。

### Layer 5: Modal Surfaces

edit sheet、timeline list island modal など、背面操作を止めて現在の操作対象を明確に移す layer です。
原則として scrim または backdrop を持ち、表示中は Timeline Canvas、Floating Commands、Header Panels、Lightweight Popovers を直接操作できません。

### Layer 6: Blocking Dialogs

削除確認や適用確認など、ユーザーの明示的な判断を待つ最上位 layer です。
Modal Surfaces の内部からも表示され得るため、通常の一時 UI より上位に置きます。

### Layer と interaction level の関係

Layer 3 の Header Panels と Layer 4 の Lightweight Popovers は、発生源と表示位置が異なるだけで、どちらも interaction level としては Quick Overlay です。
どちらも現在の作業文脈を維持したまま補助操作を差し込む UI として扱い、scrim を持たず、外側 tap は close のみに使います。

Layer 5 の Modal Surfaces は Work Surface、Layer 6 の Blocking Dialogs は Blocking Decision に対応します。
Layer number は描画と入力イベントの優先順位を示し、Level A-D は scrim / blur / absorber の強さを決めるための体験分類です。

## 基本ルール

- UI 階層は「主作業上の重要度」ではなく「入力イベントの所有権」で定義する。
- 上位 layer が表示されている間、下位 layer の action は直接実行しない。
- 下位 layer への tap は、まず上位 layer の close / dismiss に使う。
- 視覚補助だけの layer は入力権を持たせない。
- `Stack` の child 順は layer model と一致させる。
- 同時表示禁止は `Stack` の描画順だけに依存せず、各 open action で明示的に閉じる。

## Scrim / Blur / Absorber

Scrim は UI の見た目上の高さではなく、作業文脈の切り替わりを示すために使います。
一時 UI の表示は、操作がユーザーの作業文脈をどれだけ切り替えるかで分類します。

### Level A: Passive Visual

見るためだけの layer です。
上下 fade、現在時刻 marker、検索ハイライト、選択 highlight、precise drag highlight などが該当します。

- scrim: なし
- blur: なし
- tap absorber: なし
- 背面操作: そのまま可能

### Level B: Quick Overlay

現在の作業文脈を維持したまま、補助操作を軽く差し込む layer です。
header search、export panel、template popover、inline editor dismiss layer などが該当します。

- scrim: なし
- blur: なし
- tap absorber: あり
- 外側 tap: overlay を閉じるためだけに使う
- 背面 action: 同時に発火させない

Quick Overlay は背景を暗くしません。
ただし、前面 surface の視認性と分離感を保つための shadow、border、radius、surface fill は許可します。
これらは focus を奪うためではなく、背景との読み分けを成立させるために使います。

### Level C: Work Surface

作業対象を一時的に前面 UI へ移す layer です。
edit sheet、timeline list island modal、将来の full template manager などが該当します。

- scrim: あり
- blur: 原則なし
- tap absorber: あり
- 外側 tap: dismiss
- 背面 action: 不可

Work Surface は、ユーザーが「いまは Timeline Canvas ではなく、この面を操作している」と認識すべき UI です。
背景操作を止めるために scrim を使います。

### Level D: Blocking Decision

削除確認、適用確認、破壊的操作の確認など、ユーザーの明示的な判断を待つ layer です。

- barrier: platform / dialog 標準に従う
- 背面 action: 不可
- dismiss: dialog の仕様に従う

Blocking Decision は Modal Surfaces の内部からも表示され得るため、通常の一時 UI より上位に置きます。

### Blur の扱い

Blur は標準表現ではありません。
通常の Work Surface は scrim のみを使い、背面の情報が前面フォームの可読性を明確に落とす場合だけ blur を検討します。
削除確認や Blocking Decision には独自 blur を足さず、platform / dialog 標準の barrier に従います。

## 同時表示ルール

一時 UI は、単に `Stack` の前後関係で重ねるのではなく、表示中の操作面と新しく開こうとする操作面の関係で制御します。
新しい UI を開く action は、競合する一時 UI を閉じるか、現在の UI を閉じるだけで終了するかを明示します。

### Blocking Decision

Blocking Decision は、現在の操作面の上に表示します。
Work Surface 内の削除確認や template 適用確認のように、下位の操作面を残したまま、その操作に対する判断だけを最上位で求めます。

- Dialog の下に Work Surface が残ることは許可する。
- Dialog の下に Quick Overlay が残ることは原則避ける。ただし、template popover 内の適用確認のように Quick Overlay 上の操作そのものを確認する場合は許可する。
- Dialog 表示中はすべての背面 action を実行しない。

### Work Surface

Work Surface 同士は共存させません。
edit sheet、timeline list island modal、将来の full template manager などは、いずれも作業対象を一時的に前面 UI へ移す layer です。
複数の Work Surface が同時に出ると、現在の作業対象が曖昧になります。

Work Surface を開くときは、次を行います。

- Gesture transient を終了する。
- Inline editor を閉じる。
- Quick Overlay を閉じる。
- 既存の Work Surface を閉じる。
- そのうえで新しい Work Surface を開く。

Work Surface 表示中に Header Panels や Floating Commands の action が押された場合、その tap では Work Surface を閉じるだけにします。
別の action は同時に実行せず、必要なら次の tap で開きます。
これは、詳細編集中や timeline list 操作中に、意図せず別系統の操作へ即遷移することを避けるためです。

### Quick Overlay

Quick Overlay 同士は原則として共存させません。
header search、export panel、template popover は、いずれも現在の作業文脈へ軽く差し込む補助面です。
複数同時に表示すると close 対象、focus、入力イベントの所有権が曖昧になります。

Quick Overlay を開くときは、次を行います。

- Inline editor を閉じる。
- 他の Quick Overlay を閉じる。
- Work Surface が開いている場合は、新しい Quick Overlay を開かず、Work Surface を閉じるだけにする。

Quick Overlay 表示中に Timeline Canvas や Floating Commands が tap された場合、その tap は Quick Overlay の close にだけ使います。
背面 action は同時に発火させません。

### Inline Editor

Inline editor は Timeline Canvas 内の一時編集状態として扱います。
独立した overlay ではないため、上位 UI を開く前に解除します。

- Timeline Canvas tap: まず focus を外す。
- Floating Commands tap: まず focus を外し、action は次 tap に回す。
- Quick Overlay open: focus を外してから開く。
- Work Surface open: focus を外してから開く。

### Floating Commands

Floating Commands は、上位 UI 表示中は非表示または背面 layer として扱います。

- Work Surface 表示中: Floating Commands は非表示にする。
- Quick Overlay 表示中: Floating Commands は見えていてもよいが、tap は Quick Overlay の close にだけ使う。
- Header Panels 表示中: Floating Commands の action は直接実行せず、まず Header Panels を閉じる。

## Surface / Shadow Tokens

Surface token と shadow token は、部品名ではなく layer と入力イベント所有権に対応して選びます。
同じ見た目の「浮き」でも、command、card、overlay、modal ではユーザーに伝える意味が異なるため、token を流用しません。

### Canvas Surface

Timeline Canvas の土台です。

- background: `AppColors.canvas`
- shadow: なし
- border: なし
- radius: なし

Canvas Surface は画面の基礎面であり、浮かせません。

### Card Surface

block card、empty state 内の小面、list row など、Canvas 上の内容単位です。

- background: `AppColors.cardBackground`
- selected background: `AppColors.cardBackgroundSelected`
- shadow: `AppShadows.card`
- selected shadow: `AppShadows.cardSelected`
- radius: `AppRadius.md` または `AppRadius.lg`

Card Surface は操作対象の個体を示します。
画面全体の操作権は奪わず、Work Surface や Quick Overlay の shadow を流用しません。

### Header Surface

常設ヘッダーです。

- background: `AppColors.canvas`
- shadow: `AppShadows.header`
- radius: なし

Header Surface は chrome として扱い、card や modal のような角丸 surface にはしません。

### Floating Command Surface

下部 toolbar の button 群など、Canvas 上に浮く command です。

- primary background: `AppColors.accentOlive`
- neutral background: `AppColors.cardBackground`
- shadow: `AppShadows.floatingToolbar`
- radius: `AppRadius.pill`
- neutral border: `AppColors.softGray`

Floating Command Surface の shadow は command 専用です。
押せる command が Canvas 上に浮いていることを伝えるため、card、popover、modal には流用しません。

### Quick Overlay Surface

header search、export panel、template popover など、Quick Overlay に属する surface です。

- background: 原則 `AppColors.canvas` または `AppColors.cardBackground`
- shadow: `AppShadows.quickOverlay` 相当
- border: `AppColors.softGray.withValues(alpha: 0.55)` 程度
- radius: `AppRadius.xl`
- scrim: なし
- blur: なし

Quick Overlay は scrim を持たないため、shadow、border、radius、surface fill によって背景から分離します。
これらは focus を奪うためではなく、背景との読み分けを成立させるために使います。

現行 `TemplateSheet` の popover 表現にある二段 shadow は、Quick Overlay Surface の標準候補です。
今後の実装整理では、直書きではなく `AppShadows.quickOverlay` のような token へ昇格します。

### Work Surface

edit sheet、timeline list island modal、将来の full template manager など、Work Surface に属する surface です。

- background: `AppColors.canvas`
- shadow: `AppShadows.workSurface` 相当
- border: 原則なし。island 型では薄い border を許可する。
- radius: bottom sheet 型は上角のみ `AppRadius.xl`、island 型は全角 `AppRadius.xl`
- scrim: あり
- blur: 原則なし

Work Surface は scrim で背景操作を止めるため、shadow は補助表現に留めます。
Quick Overlay のように、scrim なしで背景から自力で浮くための強い shadow は使いません。

現行 `AppShadows.sheet` は Work Surface 用 token として扱います。
今後の実装整理では、用途が明確になるよう `AppShadows.workSurface` への改名または alias 化を検討します。

### Blocking Dialog Surface

削除確認や適用確認などの dialog surface です。

- background / shadow / radius: 原則 framework または dialog component 標準に従う。
- 独自 token: 原則追加しない。

Blocking Dialog Surface は確認 UI としての一貫性を優先し、layer 標準側で過度に custom しません。

### 既存 token の扱い

- `AppShadows.header`: Header Surface 専用。
- `AppShadows.floatingToolbar`: Floating Command Surface 専用。
- `AppShadows.card` / `AppShadows.cardSelected`: Card Surface 専用。
- `AppShadows.sheet`: Work Surface 用。将来的に `workSurface` へ改名または alias 化を検討する。
- `AppShadows.panel`: 名前が曖昧なため、新規 UI では原則使わない。Quick Overlay 用に再定義するか、廃止候補として扱う。
- `TemplateSheet` の popover 用直書き shadow: Quick Overlay Surface 標準として `AppShadows.quickOverlay` へ昇格予定。

## Floating Commands の action hierarchy

Floating Commands は、現在の timeline を直接編集する操作を最優先します。
toolbar 内の見た目は、action の重要度ではなく、現在の timeline に対する作用の近さで決めます。

### Primary Timeline Action

タイムライン編集の最も基本的な前進操作です。
現行 UI では「前の行動を追加」が該当します。

- toolbar 内で最大の面積を持つ。
- 横長 pill を使う。
- 原則として label を持つ。
- `AppColors.accentOlive` を使う。
- `AppShadows.floatingToolbar` を使う。
- toolbar の右側または主視線の終端に置く。
- 1つだけ置く。

Primary Timeline Action は、ユーザーが迷ったときに押す主要操作です。
複数作ると主操作が曖昧になるため、1つに限定します。

### Secondary Timeline Action

Primary と同じ編集文脈で timeline 本体に直接作用するが、頻度や意味の重みが少し下がる操作です。
現行 UI では「通過点を追加」が該当します。

- circular button を使う。
- primary と同じ `AppColors.accentOlive` を使ってよい。
- icon-only を基本とする。
- tooltip / semantics を必須とする。
- Primary Timeline Action の左に置く。
- 数を増やしすぎない。最大2個程度を目安にする。

Secondary Timeline Action は Primary の近縁操作です。
色は Primary と揃えてよいが、面積と label の有無で主従を作ります。

### Context / Management Action

現在の timeline に直接 1 要素を足すのではなく、保存済み資産、テンプレート、比較、切り替え、管理面を開く操作です。
現行 UI では template button が該当し、左下の timeline list button も画面全体ではこの系統です。

- neutral style を使う。
- background は `AppColors.cardBackground` を基本とする。
- icon は `AppColors.darkSurface` を基本とする。
- border は `AppColors.softGray` を使う。
- circular または capsule を使う。
- Primary / Secondary の編集 action group から少し距離を置く。
- Quick Overlay または Work Surface を開く。
- `AppColors.accentOlive` は原則使わない。使う場合は選択中や状態表示に限定する。

Context / Management Action は、編集の流れを支援しますが、直接 block を足す操作ではありません。
Primary と同じ見た目にしないことで、現在 timeline への直接編集 action と区別します。

### Gated / Pending Action State

Pro 判定中、Pro 専用、利用不可などの状態です。
これは action 種別ではなく、各 action に付く状態として扱います。

- pending: `AppColors.softGray` と spinner を使う。
- locked / unavailable: 表示しないか、neutral disabled とする。
- Free で入口を見せる場合も primary 色にしない。
- gated action は Primary Timeline Action の slot を占有しない。
- paywall へ遷移するだけの action を Primary Timeline Action にしない。

Pro / pending / locked action を primary 色にすると、ユーザーには「今すぐ編集を進める主要操作」に見えます。
実際には gate または管理導線であるため、neutral 側に置きます。

### 配置

下部 toolbar の基本順序は次の通りです。

```text
[Context / Management] [Secondary Timeline] [Primary Timeline]
```

現行 UI の `template`, `actionPoint`, `action` の順序はこの標準に合っています。

画面全体の Floating Commands は、左下 vertical stack と下部 toolbar で役割を分けます。

- 左下 vertical stack: timeline list、view mode など、画面状態や plan 管理。
- 下部 toolbar: 現在 timeline への編集操作と、その編集文脈に近い context action。

### Narrow Width

狭い幅では、text label より hit area と action hierarchy を優先します。

- Secondary / Context は icon-only を基本とする。
- 次に Primary の label を省略する。
- button の hit area は 56px を維持する。
- Primary / Secondary / Context の順序は変えない。
- 収まらない場合は action を横に増やさず、別 overlay / manager へ逃がす。

## 現行実装との対応

- `TimelineScreen` の `CustomScrollView`: Layer 0
- 上下 fade overlay: Layer 1
- 下部 floating toolbar、timeline list button、density toggle: Layer 2
- header search、export panel: Layer 3
- template popover: Layer 4
- edit sheet、timeline list island modal: Layer 5
- `showDialog` による確認 dialog: Layer 6

現行実装では export panel が scrim を持っていますが、操作分類としては Quick Overlay です。
今後の UI 整理では、export panel は scrim なし、透明 absorber あり、surface shadow / border ありの表現へ寄せます。
また、edit sheet の blur は既存実装上の表現であり、標準表現ではありません。
Work Surface の既定は scrim のみとし、blur は明確な理由がある場合だけ使います。

現行実装には、Work Surface 表示中に Header Panels を開く action が、Work Surface を閉じたうえで同じ tap で Header Panels を開く箇所があります。
今後の UI 整理では、この挙動を「まず Work Surface を閉じるだけ」に寄せます。

## 未確定事項

現時点で、この標準内に意図的に未確定として残している事項はありません。
- なし
