# auto-switch-type — Mac 中英文免切換輸入法

macOS 版「華碩智慧輸入法」概念：使用者不需按 Shift 切換中英文，輸入法根據打字內容自動判斷要出中文（注音）還是英文。

## 專案狀態

- **階段**：Phase 0 ✅ 完成、Phase 1 編譯驗證 ✅（2026-08-03）
- **Repo**：`git@github.com:mun375/Auto-Switch-type.git`
- **下個 session 待辦**：
  1. 安裝編譯好的小麥注音到系統實測（**Ben 已同意**；會在輸入法清單新增項目並重啟輸入法程序，注意單次登入的 kill 次數限制）
  2. 研究 `Source/InputState.swift` / `KeyHandler.mm`，設計智慧混打模式插入點
  3. 用 McBopomofo `Source/Data` 的音節資料校正手工音節表
  4. 分析用常用字表在 scratchpad 會被清掉，必要時重抓：`https://raw.githubusercontent.com/first20hours/google-10000-english/master/google-10000-english.txt`
- **已知 bug**：無

## Phase 1 編譯驗證（2026-08-03）

- 本機環境：Xcode 26.6 完整版，可編譯。
- McBopomofo shallow clone 於 `vendor/McBopomofo`（已 gitignore；正式 fork 的 repo 結構 Phase 2 再定）。
- 命令列建置注意：**必須用 `-scheme McBopomofo`**（先 `xcodebuild -resolvePackageDependencies`）；用 `-target` 不會解析外部 SPM 套件（SQLite.swift、SwiftyOpenCC）而失敗。
- Debug build 成功。安裝測試（McBopomofoInstaller）尚未執行——會動到使用者的系統輸入法，留待 Ben 同意後進行。
- 專案附有 `AGENTS.md`（AI 開發指南），關鍵檔案：`Source/InputState.swift`（狀態機）、`Source/KeyHandler.mm`（Swift↔C++ 橋接）、`Source/Engine/Mandarin/Mandarin.cpp`（注音音節處理）。智慧混打的插入點預計在 InputState 新增狀態 + KeyHandler 接上 SmartSwitchKit 分類器。

## Phase 0 結果（2026-08-03）

Swift package `SmartSwitchKit` 完成：大千鍵盤映射、注音音節 FSM（structural/strict 雙模式）、手工編碼 409 音節表、分類器、分析 CLI（`swift run analyze <常用字表>`）。15 個單元測試全過。

**準確率量測**（top-10k 英文常用字 + 23.5 萬字系統詞典）：
- 英文側：strict 模式下只有 0.64% 的常用英文字會被誤認為注音；以詞頻（Zipf）加權後，Policy v0 誤判率 **0.063%**
- 中文側：409 音節 × 5 聲調中，只有 26 個「一聲＋純字母鍵」音節與常用英文字衝突（如 u=一、t=吃、el=高、up=因、co=黑），錯誤率粗估 1.27%
- **綜合準確率 ≈ 98.9%**（中英 90:10 假設，pessimistic floor：尚未用上下文與詞頻）
- 模糊衝突集合小且可完全枚舉（70 個），Phase 2 可針對性做雙候選 UX

**已知限制**：中文側錯誤率是音節均勻分佈粗估，衝突音節中有幾個高頻字（一、吃、高、因），真實加權要等 Phase 2 接上語料；音節表為手工編碼，Phase 1 改用 McBopomofo 資料校正。
- **已決策**（2026-08-03）：定位先做自用，用得順再考慮發佈。發佈形式傾向開源免費 + 贊助（詳見下方「發佈與商業模式評估」），最終由 Ben 在 Phase 4 前拍板。
- **重大決策待定**：
  1. 確認目標使用者用的是注音（大千鍵盤）——拼音使用者 macOS 內建「繁體拼音」已有類似混打

## 發佈與商業模式評估（2026-08-03）

- 輸入法**上不了 Mac App Store**（IME 需安裝到 ~/Library/Input Methods，與 MAS 沙盒不相容；小麥、鼠鬚管、自然輸入法全是站外發佈）。所謂「上架」實際上是：自建下載頁 + 簽章公證的 pkg。
- **NT$33 買斷不成立**：收費就得自建金流 + 序號驗證 + 防盜版 + 發票義務，這套基礎設施的建置與維護成本遠超過單價 NT$33 能回收的；金流手續費（Lemon Squeezy 5%+US$0.5、Gumroad 10%）在此單價下吃掉三至五成。
- **信任門檻**：輸入法看得到使用者每一個按鍵，等同鍵盤側錄的信任等級。獨立開發者的閉源收費輸入法極難取得信任；開源是最強的信任背書，也是採用率的前提。
- **建議路線**：開源免費（MIT，延續 McBopomofo）+ 贊助連結。真正的報酬是名片效應與導流（Threads 已證明話題聲量），不是軟體銷售額。
- 開發期間 repo 維持 private，Phase 4 發佈前再由 Ben 決定是否公開。

## 可行性結論（2026-08-03 評估）

**做得到。** macOS 有官方 InputMethodKit（IMK）框架可開發第三方輸入法。市場上目前沒有任何 Mac 輸入法做「依打字內容判斷中英」；現有工具（Input Source Pro、AutoSwitchInput Pro 等）都只做「依 App 切換」，是不同類型的產品。Threads 上有明確的需求聲量（Mac 使用者羨慕 Windows 的華碩智慧輸入法），libchewing 也有 issue（#303）許願此功能未被實作——市場空缺明確。

## 核心原理

注音（大千鍵盤）按鍵序列結構性極強：合法音節 = 聲母(0–1鍵) + 介音(0–1鍵) + 韻母(0–1鍵) + 聲調(1鍵，空白/6/3/4/7)，最長 4 鍵且必以聲調結尾。英文單字的按鍵序列絕大多數不符合此文法（如 "hello" → ㄘㄍㄠㄠㄟ，連續兩個韻母又無聲調 → 判定為英文）。

判斷引擎 = 注音音節有限狀態機 + 英文詞典（trie）+ 雙側打分。難點在短序列的模糊案例（如 "so" + 空白 = ㄋㄟ˙ 也 = 英文 so）、專有名詞、縮寫——需要修正機制（一鍵切換另一種解讀）兜底。

## 技術路線（已選 A）

- **A（採用）**：以 fork [McBopomofo 小麥注音](https://github.com/openvanilla/McBopomofo)（MIT、Swift、IMK、活躍維護）為基底，新增「智慧混打模式」。選字引擎、候選視窗、IMK 整合全部現成，只需在組字狀態機中插入中英判斷層。MIT 授權允許私有 fork，須保留版權聲明。
- **B（否決）**：背景 App + CGEventTap 攔截鍵盤、判斷後切換系統輸入法並重播按鍵。脆弱（時序、安全性、與其他輸入法衝突）、需輔助使用權限、打錯要回改體驗差。不採用。

## 架構

```
┌─ SmartSwitchKit（純 Swift Package，無 UI 依賴，可單元測試）
│   ├─ 注音音節 FSM（大千鍵盤 → 注音文法）
│   ├─ 英文詞典 trie（開源字典如 SCOWL + 使用者自訂詞）
│   └─ Classifier：按鍵序列 → 中文/英文 + 信心分數
├─ IME 層（McBopomofo fork）
│   ├─ 新增「智慧混打」InputState
│   └─ 候選 UI：判斷錯誤時一鍵（如 Tab）切換另一種解讀
├─ 偏好設定面板（McBopomofo 已有，擴充）
└─ 發佈：.pkg 安裝至 ~/Library/Input Methods；公開發佈需
    Apple Developer（US$99/年）簽章 + 公證；自用免
```

## 階段規劃

- **Phase 0 — 判斷引擎 PoC**（風險核心，先做）：純 Swift CLI/測試，不碰 IMK。拿真實中英混合語料轉成按鍵序列，量測分類準確率。目標：常見情境準確率 >95% 再往下走，否則產品不成立。
- **Phase 1 — IMK 骨架**：fork McBopomofo、本機編譯安裝、跑通，熟悉其 InputState 架構。
- **Phase 2 — 整合**：智慧混打模式接進輸入法，達到「自己可以天天用」。
- **Phase 3 — 體驗打磨**：誤判修正 UX、使用者詞庫學習、設定介面、手機端不適用（純 macOS）。
- **Phase 4 — 發佈**（若決定公開）：Developer ID 簽章、公證、安裝器、GitHub release 或官網。

## 已知風險

- 判斷準確率是產品成敗唯一關鍵 → 所以 Phase 0 先行。
- IMK 文件貧乏、除錯體驗差（輸入法 crash 影響全系統打字），開發時用第二台帳號/測試用 input source。
- 模糊短字（so、la、ma…）永遠無法 100% 判對，修正 UX 必須順手。

## 參考資料

- [McBopomofo GitHub](https://github.com/openvanilla/McBopomofo)（MIT，基底候選）
- [vChewing 威注音](https://github.com/vChewing/vChewing-macOS)（純 Swift 重寫，備選參考）
- [libchewing issue #303](https://github.com/chewing/libchewing/issues/303)（同需求許願，未實作）
- [華碩智慧輸入法官方頁](https://www.asus.com/tw/content/smartinput/)（僅 Windows 10/11）
- [IMK Sample（Swift）](https://github.com/ensan-hcl/macOS_IMKitSample_2021)
