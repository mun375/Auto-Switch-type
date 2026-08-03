# 智慧混打模式 — McBopomofo 插入點設計（Phase 2 藍圖）

2026-08-03，基於 vendor/McBopomofo `ac23922` 的程式碼研究。

## 1. McBopomofo 按鍵處理流程（現況）

```
NSEvent
  → InputMethodController.handle(event:client:)        (InputMethodController.swift:219)
  → KeyHandler.handleInput(input:state:stateCallback:errorCallback:)  (KeyHandler.mm:322)
      ├─ 特殊狀態分派（候選、Big5、數字、Marking…）
      ├─ [BPMF 鍵處理] _bpmfReadingBuffer->isValidKey / combineKey    (KeyHandler.mm:464)
      │     └─ 大千鍵盤下幾乎所有字母/數字鍵都是 valid key ← 英文會被吃進注音
      ├─ [音節完成] 聲調鍵到位 → composeReading                        (KeyHandler.mm:506)
      │     ├─ _languageModel->hasUnigrams(reading) 失敗 → errorCallback ← 英文訊號！
      │     └─ 成功 → _grid->insertReading() + _walk()（Viterbi 走格）
      ├─ 空白/Tab/游標/Backspace/Enter 各自處理
      └─ 大寫字母 → letterBehavior 決定直接輸出                        (KeyHandler.mm:795)
  → stateCallback → InputMethodController.handle(state:client:)       (InputMethodController.swift:393)
      └─ 依 InputState 子類別更新 UI / commit 文字
```

關鍵資料結構（都在 KeyHandler 內）：
- `_bpmfReadingBuffer`（C++ `BopomofoReadingBuffer`）：目前打到一半、還沒下聲調的單一音節。
- `_grid`（C++ `ReadingGrid`）：已完成音節序列 + 語言模型走格結果。支援
  `insertReading` / `deleteReadingBeforeCursor`（Backspace 就靠它回退，KeyHandler.mm:482 附近也示範過重組讀音）。
- `InputState`（Swift，不可變物件）：狀態機的「目前畫面」，controller 只依它渲染。

## 2. 插入點設計

### 新增元件

1. **`_rawKeyBuffer`（KeyHandler 新增成員，std::string）**
   記錄「這個詞」從開始到現在使用者敲的原始 ASCII 鍵序。生命週期＝一個
   token：commit、空白、Esc、狀態清空時歸零；Backspace 同步 pop。

2. **SmartSwitchKit 橋接**（Swift → ObjC++）
   `Source/SmartSwitch/SmartSwitchBridge.swift`，`@objc class SmartClassifierBridge`，
   經 `McBopomofo-Swift.h` 讓 KeyHandler.mm 呼叫：
   `classify(rawKeys:followedBySpace:) → {chinese | english | ambiguous | undecidedPrefix}`。
   SmartSwitchKit 以 local SPM package 掛進 app target（與 `Packages/` 內其他套件同法）。

3. **SmartSwitchKit 需要的新 API：`parsePrefix`（增量判斷）**
   現有 `ZhuyinParser.parse` 只能判斷完整 token；smart 模式需要「這串鍵還有沒有
   可能繼續長成合法注音」的前綴判斷（回傳 undecidedPrefix / impossible）。
   這是 Phase 2 第一個 SmartSwitchKit 工作項。

4. **新 InputState：`InputState.SmartEnglish`（NotEmpty 子類別）**
   composing buffer 顯示原始 ASCII（底線樣式沿用 Inputting），代表「這個詞已判定
   為英文、尚未 commit」。`InputMethodController.handle(state:)` 的 switch 加一個
   case（顯示邏輯與 Inputting 幾乎相同）。判錯時 Tab 切回注音解讀。

### KeyHandler.handleInput 的三個掛鉤點

全部以 `Preferences.smartMixedModeEnabled && _inputMode == InputModeBopomofo` 為前提。

**掛鉤 A — BPMF 鍵處理之前（KeyHandler.mm:461 前）**
每個可列印鍵先進 `_rawKeyBuffer`，呼叫分類器：
- `undecidedPrefix`（還可能是注音）→ 照舊走 BPMF 路徑，畫面顯示注音。
- `impossible`（已不可能是注音，如連兩個韻母無聲調）→ **轉換**：
  1. `_bpmfReadingBuffer->clear()`
  2. 把這個 token 已插入 `_grid` 的讀音用 `deleteReadingBeforeCursor()` 逐一回退
     （需要記住 token 開始後插了幾個 reading——`_rawKeyBuffer` 的斷點即是）
  3. 進入 `SmartEnglish` 狀態，buffer 顯示 `_rawKeyBuffer` 原文
  之後的鍵直接 append 進 SmartEnglish，直到空白/Enter commit。

**掛鉤 B — composeReading 的 hasUnigrams 失敗分支（KeyHandler.mm:516）**
現況是 errorCallback（叫聲）；smart 模式下這是強烈英文訊號 → 走掛鉤 A 的轉換流程
而不是報錯。

**掛鉤 C — token 結束時（空白鍵，KeyHandler.mm:595 附近）**
空白＝一聲鍵，也是英文分詞鍵，是最大歧義來源：
- 分類器判 `chinese` → 照舊（空白當一聲/選字）。
- 判 `english` → 轉換 + commit「原文 + 空白」。
- 判 `ambiguous`（如 "so"）→ 依 Policy v0 預設判英文（Phase 0 量測：加權錯誤
  0.061%），並在 tooltip 提示 Tab 可切換另一解讀；Tab 的 undo 需要能把剛 commit
  的原文換成注音解讀（先做「commit 前」的切換，commit 後反悔留 Phase 3）。

### 大寫（Shift）行為
維持 McBopomofo 現有 letterBehavior 邏輯：大寫字母＝明確英文，直接輸出，同時把
`_rawKeyBuffer` 標記為英文 token（後續小寫字母不再嘗試注音解讀，直到分詞）。

## 3. 為什麼不在 InputMethodController 層做

controller 只做事件轉發與 UI 渲染，所有組字知識（reading buffer、grid）都在
KeyHandler；轉換需要回退 grid 讀音，只有 KeyHandler 摸得到。SmartSwitchKit 保持
純函式庫（可測試），KeyHandler 只多一層薄薄的呼叫。

## 4. Phase 2 實作順序建議

1. SmartSwitchKit：`parsePrefix` 增量 API + 單元測試（含 rareSyllables 降權）。
2. Fork 內掛 SmartSwitchKit package + `SmartClassifierBridge`（先只 log 判斷結果，
   不改行為——用 Console.app 對照實際打字驗證分類器）。
3. `_rawKeyBuffer` + 掛鉤 A/B（英文自動轉換），新狀態 SmartEnglish。
4. 掛鉤 C（空白歧義 + Tab 切換）。
5. Preferences 加開關（預設關，開發者自用先）。

風險備忘：
- `deleteReadingBeforeCursor` 回退法要處理游標不在行尾的編輯情境——v1 可先限定
  「smart 轉換只在游標位於行尾時發生」，中段編輯視為進階案例。
- IMK 除錯：輸入法 crash 影響全系統，開發時先 log-only（步驟 2）再動行為。
