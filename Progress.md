# 免切注音 Switchless（原 auto-switch-type）— Mac 中英文免切換輸入法

macOS 版「華碩智慧輸入法」概念：使用者不需按 Shift 切換中英文，輸入法根據打字內容自動判斷要出中文（注音）還是英文。

**產品身分（2026-08-04 定案）**：中文名「免切注音」、英文名 Switchless、App 為 `Switchless.app`、bundle ID `tw.benjiang.inputmethod.Switchless`、使用者資料夾 `~/Library/Application Support/Switchless/`。與官方小麥注音完全獨立，可並存。

## 專案狀態

- **階段**：Phase 0 ✅、Phase 1 ✅、Phase 2 ✅（掛鉤 A/B/C、數字直打、Preferences UI）、**Phase 3 第一項「commit 後反悔」（Ben 初步實測 OK）、第二項「使用者自訂英文詞庫」✅ Ben 實測通過、第三項「改名 rebrand」✅ 已完成待 Ben 實測（2026-08-04）**
- **Repo**：`git@github.com:mun375/Auto-Switch-type.git`（private，push 不會觸發任何部署）
- **下個 session 待辦**：Ben 實測 rebrand 後的裝機（見下方 rebrand 驗收清單，第一步要在系統設定重新加輸入來源）；補跑 commit 後反悔驗收清單第 4、7 條；之後是 Phase 4（詞典換 SCOWL、簽章公證 pkg + 發佈頁）。
- **已知 bug**：無
- **兩個 repo**（都是 private，push 都不會觸發部署）：
  - `git@github.com:mun375/Auto-Switch-type.git` — 主專案（SmartSwitchKit、scripts、文件）。分支 `main`。
  - `git@github.com:mun375/Auto-Switch-type-ime.git` — McBopomofo fork（IME 端所有改動）。**在 `vendor/McBopomofo` 裡的 remote 名稱是 `fork`，`origin` 仍指向上游 openvanilla/McBopomofo**（保留給之後 rebase 上游用）。預設分支 `smart-mixed-mode`。
  - `vendor/McBopomofo` 在主 repo 裡仍是 gitignore，兩個 repo 各自獨立 commit／push。**改了 IME 端的東西要記得 `git -C vendor/McBopomofo push fork smart-mixed-mode`。**
  - 2026-08-04 建立時把原本的 shallow clone `fetch --unshallow` 補成完整歷史（否則 GitHub 拒收），`.git` 從 3.3M 變 85M。上游 MIT 版權聲明原封保留。
- **已知限制（v1 刻意保留）**：
  - 英文 token 一旦成立，後續按鍵都當英文直到空白/Enter——**英轉中必須打空白分詞**（Ben 實測確認此體感）。自動偵測英轉中邊界是進階題，Phase 3 再評估。
  - 游標不在行尾時智慧轉換自動停用。
  - 英文 token 中的 `/` 等少數符號若無半形 reading 會 fallback 到通用查找；`,` `.` `;` `/` `-` 已有明確對應表（shift 字元命名問題，見下）。
  - 空白定案後的 ↑ 切換在「下一鍵之前」有效；**Enter commit 後仍可再按 ↑ 反悔一次（2026-08-04 新增，可連按來回切換）**，但打了其他鍵就真正定案。commit 中間位置的 token（早已被後續按鍵定案者）不可反悔。

## 新 bundle ID 的輸入法要登出才會出現（2026-08-04，rebrand 後實測）

改名後 `Switchless.app` 裝好了、註冊了，但**系統設定的「+ 加入輸入方式」清單裡完全找不到「免切注音」**。逐項排除後的結論：**macOS 只在登入時掃描 `~/Library/Input Methods` 建立輸入法清單，新的 bundle ID 要登出再登入才會被系統收錄。**

- 排除掉的可能原因（都有實測證據，不用再查）：
  - Bundle 本身沒問題——TIS 查得到，`Category` / `Type` / `EnableCapable=true` / `Languages=zh-Hant` 與能用的 McBopomofo **逐項相同**，唯一差別是 `Enabled=false`。
  - Info.plist 格式正確（Xcode 會把我加的 XML 註解剝掉）、圖示可被 ImageIO 解碼、adhoc 簽章驗證通過、無 quarantine。
  - LaunchServices 只註冊了安裝版一份。
  - `TISRegisterInputSource` + `TISEnableInputSource` **一律回 0 (noErr) 但不生效**——AI 跑不生效，**Ben 自己跑也不生效**（Phase 1 那次「Ben 跑就成功」是因為當時 bundle ID 早就被系統收錄過，只是重新啟用）。
  - 重開 System Settings、`lsregister -f` 重新註冊都沒用。
- 上游 `Source/Installer/AppDelegate.swift` 做的事和我們的腳本完全一樣（register 然後 enable），沒有額外招數；它自己的註解就寫了 macOS 12 以上 `kTISPropertyInputSourceIsEnabled` 可能是 true 但輸入法不在使用者的輸入選單裡——正是這個狀況。上游 README 對「裝了看不到」的說法也是登出再登入。
- **這是換 bundle ID 的一次性代價**：之後改程式碼沿用同一個 ID 就不會再遇到（前八次 session 都在覆蓋同一個 bundle ID，所以從沒踩到）。
- **Phase 4 必辦**：發佈頁與 pkg 安裝完成畫面必須明講「第一次安裝請登出再登入」，否則每個新使用者都會以為裝失敗。上游安裝程式有這句提示（`McBopomofo is upgraded, but please log out or reboot…`），我們的發佈流程要保留同等的提示。

## 輸入法從狀態列選單消失（2026-08-04 診斷 + 修好）

> **rebrand 後補充**：安裝的 App 現在叫 `Switchless.app`、bundle ID `tw.benjiang.inputmethod.Switchless`；`scripts/install_ime.sh` 已同步。本節其餘診斷邏輯不變，把 `McBopomofo.app` 讀成 `Switchless.app` 即可。Xcode 專案名沒改，所以 DerivedData 仍是 `McBopomofo-*`。

Ben 回報狀態列的輸入法選單裡看不到小麥注音。**根因不是註冊失敗，是註冊了三份。**

- Xcode target 有 `RegisterWithLaunchServices` 建置階段，所以**每次 build 都會把建置目錄那份也註冊進 LaunchServices**，和安裝版共用同一個 bundle ID。當時同時註冊著三個路徑：`~/Library/Input Methods/`、DerivedData、`vendor/McBopomofo/build/Debug/`。
- 後果：系統實際啟動的是 DerivedData 那份（實測有兩個 McBopomofo 程序在跑），而且 `AppleEnabledInputSources` 裡的小麥注音項目被系統整個丟掉（只剩在 `AppleInputSourceHistory`）——選單自然看不到。
- **修法**：把非安裝版的路徑 `lsregister -u` 解除註冊、只留 `~/Library/Input Methods/McBopomofo.app` 再 `lsregister -f`。已寫成 `scripts/install_ime.sh`，之後裝機一律跑它。
- **殘留**：`TISEnableInputSource` 從命令列腳本呼叫**回傳 noErr 但不會寫進系統啟用清單**（跨程序不生效），所以最後一步 Ben 要自己在系統設定裡加：
  **系統設定 → 鍵盤 → 輸入來源「編輯…」→ 左下角 `+` → 繁體中文 → 小麥注音（含「小麥注音-精簡模式」共兩項）→ 加入**。加完狀態列選單就會出現。
- 診斷指令備忘：`defaults read com.apple.HIToolbox AppleEnabledInputSources`（系統真正啟用的清單）；`lsregister -dump | grep McBopomofo.app`（看註冊了幾份）。TIS API 自己回報的 `IsEnabled` 只反映呼叫端程序的快取，不可信。

## 模型分工表（Ben 用：session 該叫誰）

原則：**動 `KeyHandler.mm`／C++ 組字引擎／判斷邏輯設計 → Fable 5；UI 接線、資料處理、文件、打包 → Opus**。Opus session 若遇到輸入法 crash／打字行為異常的除錯，停下換 Fable 5 接手。

| 順序 | 工作 | 模型 |
|---|---|---|
| ✅ 2026-08-04 | 誤判修正 UX（commit 後反悔、tooltip） | Fable 5（已完成，待實測） |
| ✅ 2026-08-04 | 使用者自訂英文詞庫 | Opus（已完成，Ben 實測通過） |
| ✅ 2026-08-04 | 改名 rebrand（名稱/bundle ID/圖示/在地化；尊重上游、保留 MIT 版權聲明） | Opus（已完成，待實測） |
| 下一次 | 正式 App icon 設計（rebrand 只做了換色佔位） | Opus |
| Phase 4 | 詞典換 SCOWL + 重跑準確率 | Opus |
| Phase 4 | 簽章公證 pkg + 發佈頁（含自建更新端點） | Opus |
| 隨時 | 文件、小修、建置裝機 | Opus |

## Phase 3：改名 rebrand 完成（2026-08-04，第九次 session；待 Ben 實測）

從 McBopomofo 分支變成有獨立身分的產品「**免切注音 / Switchless**」，與官方小麥注音完全獨立、可並存。

**命名決策**（Ben 從三案中選定）：直白派勝出——功能寫在名字上，搜尋友善（會有人搜「mac 注音 不用切換」）。另外兩案是「順打注音 / Glide」（意象派）與「兩全注音 / Duet」（典雅派）。

| 項目 | 值 |
|---|---|
| 中文名 | 免切注音（傳統模式為「免切注音（傳統）」） |
| 英文名 | Switchless |
| App | `Switchless.app` |
| bundle ID | `tw.benjiang.inputmethod.Switchless` |
| 輸入模式 ID | `…Switchless.Bopomofo` / `…Switchless.PlainBopomofo` |
| 使用者資料夾 | `~/Library/Application Support/Switchless/` |
| log subsystem | `tw.benjiang.inputmethod.Switchless`（category 仍是 `SmartSwitch`） |

**兩個順帶必修的問題**（不改就是 bug）：

1. **更新檢查會把使用者送去上游**。`UpdateInfoEndpoint` 指向 `mcbopomofo.openvanilla.org`，且 `CheckUpdateAutomatically` 預設 true——不處理的話我們的 App 會跳「有新版小麥注音」把人導到上游下載頁。已移除 Info.plist 兩個 key 與選單「檢查更新…」項，兩處都留了註解說明 Phase 4 自建端點後怎麼還原。
2. **改 bundle ID = 偏好設定與使用者詞庫全部歸零**，包括 `SmartMixedModeEnabled`——這功能是整個 fork 的重點，裝完卻是關的。已做一次性搬移（見下）。

**一次性搬移**（`UserPhraseLocationHelper.migrateFromLegacyBundleIfNeeded()`，在 `applicationDidFinishLaunching` 最前面呼叫）：

- **偏好設定**：從舊 domain `persistentDomain(forName:)` 讀出來，**只補新 domain 沒有的 key**（改過的設定永遠勝出），寫入後設 `SwitchlessDidMigrateFromMcBopomofo` 標記；標記先寫再搬，半途失敗不會無限重試。
- **使用者詞庫**：`~/Library/Application Support/McBopomofo/` → `Switchless/`，**複製而非搬移**（還在用官方小麥注音的人不受影響）；目標資料夾一存在就整個跳過，所以不可能覆蓋較新的編輯，每次啟動呼叫都安全。使用者設了自訂路徑時不搬（預設資料夾根本沒用到）。
- 順序必須是先設定後檔案：檔案搬移要讀 `useCustomUserPhraseLocation`，那是設定搬移的產物。

**內部命名刻意不動**：`McBopomofoInputMethodController`、C++ `McBopomofo::` namespace、`McBopomofoLM`、Xcode target 名、`McBopomofo.xcodeproj`（所以 DerivedData 仍叫 `McBopomofo-*`）。這些使用者看不到，改了是純風險零收益，保留也是對上游的自然致敬。作法是**只覆寫 `PRODUCT_NAME = Switchless` 並固定 `PRODUCT_MODULE_NAME = McBopomofo`**——後者是關鍵，不設的話 Swift 產生的橋接標頭會變 `Switchless-Swift.h`，`LanguageModelManager.mm` 的 `#import "McBopomofo-Swift.h"` 會編不過。`TEST_HOST` 也跟著改成 `Switchless.app/Contents/MacOS/Switchless`。

**在地化的作法**：`Localizable.strings` **只改 value、不動 key**（key 就是 `NSLocalizedString` 的第一個參數，改 key 要同步改所有呼叫端，純風險）。所以檔案裡會看到 `"About McBopomofo…" = "關於免切注音…";` 這種左右不一致，是刻意的。例外是 `ServicesMenu.strings`：它的 key 必須與 Info.plist `NSServices` 的 `NSMenuItem.default` 字面相同，所以那一條 key/value 都改了。

**改動檔案**：

- vendor fork（分支 `smart-mixed-mode`）：`project.pbxproj`、`McBopomofo-Info.plist`、三份 `InfoPlist.strings`、三份 `Localizable.strings`、兩份 `ServicesMenu.strings`、兩份 `MainMenu.xib`、三份 `Credits.rtf`、十份 `template-*.txt`、`KeyHandler.mm`（兩個 InputMode 常數）、`SmartClassifierBridge.swift`（log subsystem）、`InputMethodController.swift`（移除更新選單項）、`Preferences.swift`（資料夾改名 + 搬移）、`AppDelegate.swift`（搬移掛點）、Installer 全套（路徑常數、字串、xib、plist）、`README.markdown`（開頭加分支說明）、14 個圖示檔。
- 主 repo：`scripts/install_ime.sh`（改為裝 `Switchless.app`，並偵測舊 fork 還在時印出移除指令——但**不自動刪**）、`scripts/register_ime.swift`（新 bundle ID）、新增 `scripts/recolor_icons.py`。

**圖示**：沿用上游造型，只做色相旋轉 214°→168°（深藍 → 墨綠 `(21,104,89)`），飽和度與明度不動，所以所有陰影與抗鋸齒像素一致；灰階像素（字形本身）因 S<0.05 不受影響。目的只是讓兩者在選單列不會長得一模一樣。**這是佔位，正式 icon 另開一輪**（`scripts/recolor_icons.py` 可重跑，之後與上游同步圖示時還用得到）。

**Credits.rtf 重寫**：上游把中文存成 Big5 escape，diff 完全不可讀。改用 `\uNNNN` escape 重新產生（產生器留在 scratchpad，內容已定案不需再跑）。內容是「基於小麥注音 McBopomofo（MIT 授權）」＋三個連結：專案頁面、上游專案、問題回報。**注意：專案頁面連到 private repo，發佈前要改**。

**上游授權處理**：`LICENSE.txt` 原封不動；`NSHumanReadableCopyright`（主程式 + 安裝程式 + 三份 InfoPlist.strings）改成「上游版權 + Switchless 修改版權 + MIT」並列；README 開頭寫明是分支與原作者。`template-*.txt` 裡的上游 wiki 連結保留（檔案格式我們原封繼承，那份手冊是準確的），但加註「上游小麥注音使用手冊（檔案格式與免切注音相同）」，並把範例詞從「小麥注音」換成「免切注音 ㄇㄧㄢˇ-ㄑㄧㄝ-ㄓㄨˋ-ㄧㄣ」——那行會寫進使用者自己的資料檔。

**驗證結果（AI 實際跑過，非推測）**：

- ✅ SmartSwitchKit 42 測試全過、vendor 125 測試全過（測試進程名已是 `Switchless`）。
- ✅ Debug build 成功；產物 `Switchless.app`，`CFBundleIdentifier` / `TISInputSourceID` = `tw.benjiang.inputmethod.Switchless`、`InputMethodConnectionName` = `Switchless_1_Connection`、`UpdateInfoEndpoint` 確認不存在、zh-Hant 顯示名為「免切注音」。
- ✅ **搬移端到端實測**：清空新 domain 與新資料夾後啟動一次 → log 出現 `imported 9 setting(s)` 與 `migrated user phrase files from …/McBopomofo to …/Switchless`；`SmartMixedModeEnabled` 確認搬成 1（智慧混打裝完就是開的）；六個詞庫檔全部到位，`smart-english.txt` MD5 與來源一致。
- ✅ **熱重載在新路徑仍運作**（FSEvent 監看路徑變了，這是真有風險的一項）：加一行 `ai` 存檔 → 六秒內 log 出現 `user English lexicon loaded: 1 word(s)`；驗完已還原原檔並比對 MD5。
- ✅ 已裝到 `~/Library/Input Methods/Switchless.app`，LaunchServices 只留安裝版（建置目錄那份已解除註冊）。
- 未跑：實際敲鍵盤打字（AI 無 TextEdit 存取權，只能由 Ben 做）。

**Ben 驗收清單**：

1. **先登出再登入，然後加輸入來源**（換 bundle ID 後系統當它是全新輸入法，而且要登入時才會掃到——見上方專節）：系統設定 → 鍵盤 → 輸入來源「編輯…」→ 左下角 `+` → 繁體中文 → 加入「免切注音」與「免切注音（傳統）」。
2. 選單列切到「免切注音」，圖示應是**墨綠**色（舊的深藍是 pre-rebrand 那份）。
3. 打字回歸：純中文長句、`hello`、`up`+空白 → 因、`ai`+空白（詞庫目前是空的，所以會出「摸」——想驗詞庫就先加 `ai` 進去）。
4. 輸入法選單 → 應**沒有**「檢查更新…」；「免切注音偏好設定」打得開，智慧混打開關應該是**開**的。
5. 選單「編輯智慧混打英文詞庫」→ 開啟的應是 `~/Library/Application Support/Switchless/smart-english.txt`。
6. 關於視窗（選單「關於免切注音…」）→ 版權欄應同時有上游與 Switchless 兩行。
7. 確認無誤後可移除 pre-rebrand 那份（`~/Library/Input Methods/McBopomofo.app`）——**我沒有自動刪**，指令在 `install_ime.sh` 執行完會印出來。舊資料夾 `~/Library/Application Support/McBopomofo/` 建議也留著一陣子當備援。

**備忘**：vendor 測試套件會污染真實的偏好設定 domain（`KeyHandlerBopomofoTests` 的 setUp/tearDown 會寫 `SmartMixedModeEnabled`），現在污染的是 Switchless domain。這次就踩到一次——中止的測試先把新 domain 寫了 0，導致搬移依「不覆蓋既有值」的設計跳過該 key，看起來像搬移失效。**日後驗搬移一定要先清空 domain 再驗**。

## Phase 3：使用者自訂英文詞庫完成（2026-08-04，第八次 session；Ben 實測通過）

Ben 可以自己列一份「這些字一律當英文」的清單，蓋過分類器的預設判斷。

**為什麼需要**（先量了才做）：分類器在「鍵序剛好也是合法注音」時才會出錯，實測掃過一批常見科技詞，真正衝突的只有 7 個——`ai`→摸（ㄇㄛ）、`ui`→唷（ㄧㄛ）、`np`→森（ㄙㄣ）、`yo`→ㄗㄟ，加上原本就 ambiguous 的 `go`/`so`/`up`。其中 **`ai` 最痛**：它有 unigram，掛鉤 B 救不了，打「ai」+空白現在會出「摸」。其餘像 `figma`、`vercel`、`npm` 這種長詞，掛鉤 A 早就判英文了，不需要進詞庫。

**設計**：新增 `Classifier.userEnglish`（獨立於內建 `lexicon`）。差別在**判決強度**——內建詞庫命中只給 `.ambiguous`，而掛鉤 C 的政策是 ambiguous→判中文，所以把字加進內建詞庫是**沒有用的**；`userEnglish` 命中直接回 `.english`。注音解讀照樣回傳，所以 ↑ 切換與 commit 後反悔都能用（打「ai」出 `ai`，按 ↑ 變「摸」）。這也讓使用者能翻掉 `up`→因 這種預設。反方向（強迫某字保持中文）v1 不做：會受影響的只有 `no`/`uk` 兩個罕見音節，需求極低。

- **檔案**：`~/Library/Application Support/McBopomofo/smart-english.txt`，一行一字、`#` 註解、大小寫不拘。放在既有使用者詞庫資料夾，因此**自動沿用**資料夾搬移偏好設定與 FSEvent 監看器——存檔即生效，不必重開輸入法。第一次從選單開啟時才建檔，內容是一段中文說明模板。
- **選單**：輸入法選單「使用者詞彙」區塊新增「編輯智慧混打英文詞庫」，僅在 `SmartMixedModeEnabled` 開啟且非 plain bopomofo 模式時顯示。三份 Localizable.strings 都加了字串（這次沒有硬寫中文）。
- **執行緒**：`SmartClassifierBridge.classifier` 從 `let` 改成 `var` + `NSLock`（主執行緒重載 vs 輸入執行緒讀取）。
- **改動檔案**：SmartSwitchKit — Classifier.swift（`userEnglish` + init 參數 + 判決分支）、Lexicon.swift（`parseUserList`）；vendor fork（分支 `smart-mixed-mode`）— SmartClassifierBridge.swift（新 `SmartEnglishLexicon` 類別、鎖、`reloadUserLexicon`；注意 `load()` 會和 `NSObject.load` 撞名，用 `loadWords()`）、AppDelegate.swift（開檔動作 + 兩處重載掛點）、InputMethodController.swift（選單項 + forwarding + reloadUserPhrases 也重載）、三份 Localizable.strings。KeyHandler.mm 零改動。
- **驗證**：SmartSwitchKit 42 測試全過（36 → 42，新增 6 個）、vendor 125 測試全過、Debug build 成功並已裝機。
- **新增 `scripts/install_ime.sh`**：複製建置產物到 `~/Library/Input Methods`，然後把**除了安裝版以外**的所有 McBopomofo.app 從 LaunchServices 解除註冊。以後裝機一律跑這支（見下方「輸入法從選單消失」）。

**驗收結果（2026-08-04）**：

- ✅ 選單項出現、點擊建檔（`smart-english.txt` 以中文說明模板建立）。
- ✅ 熱重載：加一行 `ai` 存檔後**不重開輸入法**，執行中的 IME 四秒內 log 出現 `user English lexicon loaded: 1 word(s)`。
- ✅ 判決翻轉：拿磁碟上的實際檔案跑分類器，`ai` chinese→english（另一解讀保留 ㄇㄛ），`ui`/`up`/`hello`/`rup` 全部不動——沒有誤傷。
- ✅ **Ben 實測打字：`ai`+空白 出 `ai`**。
- 未跑：刪除詞條後回復、加 `up` 翻掉預設政策、長句回歸——邏輯與 `ai` 同一條路徑，風險低。
- 備忘：AI 這邊的 TextEdit computer-use 存取被拒，實際敲鍵盤只能由 Ben 做；其餘環節都能從命令列驗。

## Phase 3：commit 後反悔完成（2026-08-04，第七次 session；待 Ben 實測）

Phase 2 的 ↑ 切換原本在 Enter commit 時失效；本次讓它**跨過 commit 再活一個按鍵**：Enter 送出後緊接著按 ↑，輸入法會把「剛送出的字尾」在目標 App 裡原地換成另一種解讀（因 ↔ `up `、`no` ↔ 㩙），可連按 ↑ 來回切換；按任何其他鍵（或換 App）就真正定案。

**機制**（安全第一，寧可不動作也不誤改使用者文字）：

- **記錄建立**：兩個 Enter commit 路徑會把「送出的字尾＋另一解讀」存成 post-commit undo 記錄——(1) 空白定案記錄還有效時按 plain Enter（`up`+空白+Enter，含先按過 ↑ 切換再 Enter 的情況）；(2) 掛鉤 C 的 Enter 直接 commit（`no`+Enter，僅 canFlipBack 者）。兩種解讀先在 grid 裡各 render 一次、取**共同前綴之後的差異字尾**（處理詞組重排，如「原因」→「原up 」只換「因」以後）。掛鉤 B（如 hello、no3）無另一解讀，照舊不設記錄。
- **取代流程**（InputMethodController，新 `InputState.SwappingCommitted`）：以 IMK `selectedRange` 取得游標位置 → `attributedSubstring` **驗證游標前文字與送出的字尾完全一致** → 才 `insertText(replacementRange:)` 原地取代 → 回報 KeyHandler 翻轉記錄（`smartCommitUndoDidApply/DidFail`，同步呼叫）。驗證不過（終端機等不支援 selectedRange 的 App、游標被滑鼠移走、簡繁轉換開啟導致送出文字被轉換）→ 記錄作廢、↑ 放行給 App 當一般游標鍵，**絕不誤改文字**。
- **↑ 攔截條件**：只攔 plain ↑（無修飾鍵；Shift+↑ 選字、直排模式都不攔），且限 Empty 狀態、smart mode 開啟、記錄有效。一鍵窗口，其他鍵立即失效；`clear()`（換 App、Esc 等）也失效。
- **殘留風險（已知、機率低）**：commit 後用滑鼠點到別處、且新游標前的文字恰好等於剛送出的字尾、且下一鍵就按 ↑——會誤換那裡的字。因驗證靠文字比對而非絕對位置，IME 在 Empty 狀態收不到滑鼠事件。再按一次 ↑ 可換回來。
- **改動檔案**（vendor 分支 `smart-mixed-mode`，commit `18987ae`）：KeyHandler.mm（undo ivars、入口記錄存活規則改為「空白記錄在 plain Enter 時轉成 undo 記錄」、↑ 攔截、`_smartToggledSpaceRecordInputtingState` helper 抽取（原空白後 ↑ 切換改用之）、兩個 Enter 路徑、`_smartSetCommitUndoWithCommitted:alternate:` 共同前綴 diff（含 surrogate pair 保護））、KeyHandler.h（DidApply/DidFail 宣告）、InputState.swift（SwappingCommitted）、InputMethodController.swift（swap handler + switch case）、SmartClassifierBridge.swift（undo 成功/被擋 log）。SmartSwitchKit 零改動。
- **附帶修正**：vendor 測試套件原本有 3 個失敗（本機 `SmartMixedModeEnabled=1` 洩漏進測試環境，是既有問題非本次回歸）——KeyHandlerBopomofoTests 的 setUp/tearDown 現在會保存並強制關閉 smart mode。**125 個 vendor 測試 + 36 個 SmartSwitchKit 測試全過**。
- Debug build 成功、已裝機（`~/Library/Input Methods/McBopomofo.app`）。Ben 初步實測 OK；驗收清單第 4、7 條（誤攔一般 ↑、終端機安全放行）下次補測。
- **裝機備忘（session 尾發現）**：build 的 `RegisterWithLaunchServices` 會把 DerivedData 那份也註冊進 LaunchServices，系統可能啟動到建置目錄的舊份——已用 `lsregister -u <DerivedData 路徑>` 解除註冊並重新註冊安裝版。之後每次裝機建議照做。**（2026-08-04 更新：這個問題後來真的害輸入法從選單消失，已寫成 `scripts/install_ime.sh`，並修正本節「一直是啟用狀態」的說法——見上方「輸入法從狀態列選單消失」。）**

**Ben 驗收清單**（開 log：`/usr/bin/log stream --predicate "subsystem == 'org.openvanilla.inputmethod.McBopomofo' AND category == 'SmartSwitch'"`，在 TextEdit/備忘錄測）：

1. `up`+空白+Enter → 送出「因」；按 ↑ → 變 `up `；再按 ↑ → 變回「因」；打別的字 → 定案，之後 ↑ 恢復游標鍵。
2. `no`+Enter → 送出 `no`；按 ↑ → 變 㩙；再按 ↑ → 變回 `no`。
3. `up`+空白 → 因，先按 ↑ 切成 `up `，再 Enter 送出 → 按 ↑ → 變回「因」（切換過再 commit 也能反悔）。
4. `因為`（u p 空白 w p 4）+Enter → 送出後按 ↑ **不應有任何反應**（記錄早被 w 鍵定案）、↑ 當一般游標鍵。
5. `hello`+Enter、`so`+空白+Enter → 按 ↑ 無反應（無另一解讀，↑ 放行）。
6. 送出「因」後先用滑鼠點到文件其他地方再按 ↑ → 若前面的字不是「因」應無反應（log 會出現 post-commit undo blocked）。
7. 終端機（Terminal.app）裡 `up`+空白+Enter 後按 ↑ → 文字不變、↑ 正常送出（blocked log）。
8. 回歸：純中文長句、`x.com`、Backspace、候選字視窗（↓）行為不變。

## Preferences 開關 UI 完成（2026-08-04，第六次 session）

Phase 2 最後一項：`SmartMixedModeEnabled` 從只能 `defaults write` 變成偏好設定面板上的開關。

- **位置**：基本頁籤，兩個鍵盤配置選單之下、選字鍵之上（自成一段，上下各一條 Divider）。標籤「智慧中英混打：」＋勾選框「免切換直接混打中英文」＋下方 caption 說明。
- **大千限定的處理**：`keyboardLayout != .standard` 時開關 disabled（分類器只模型化大千），caption 換成「此功能目前只支援大千（標準）注音鍵盤配置。」；大千時 caption 是「輸入時自動辨識英文字並直接以字面輸出。判斷不如預期時，按 ↑ 可切換成另一種解讀。」——把 ↑ 這個唯一的救援鍵寫進 UI，不然使用者不會知道。
- **改動檔案**（vendor 分支 `smart-mixed-mode`，commit `014c3e5`）：PreferencesModel.swift（`smartMixedModeEnabled` + `isSmartMixedModeAvailable`）、PreferencesView.swift（基本頁籤兩個 PreferenceRow）、Preferences.swift（註解更新＋系統報告加一行）、三份 Localizable.strings（Base/en/zh-Hant）。SmartSwitchKit 與 KeyHandler.mm 零改動。
- **驗證**：build 成功、36 測試全過；截圖確認開／關兩種狀態的排版與文案（切到「倚天」→ 開關變灰、caption 換成限制說明，切回「標準」→ 恢復）；點開關實際寫入 `SmartMixedModeEnabled`（1↔0 來回驗證，最後留在 1）。新版已裝到 `~/Library/Input Methods/McBopomofo.app`。
- **驗證手法備忘**：偏好設定視窗平常只能從輸入法選單開，UI 截圖不好取。作法是暫時在 `main.swift` 加一個 `showprefs` 參數直接開視窗（用 `MainActor.assumeIsolated` 包住），截完圖再移除——這段**沒有留在 repo**。另外 shell 沒有螢幕錄製權限，`screencapture` 一律失敗，要用 computer-use 的 screenshot（request_access 傳 bundle ID `org.openvanilla.inputmethod.McBopomofo`，因為輸入法不在 /Applications 清單裡）。

## 掛鉤 C 完成（2026-08-03，第五次 session；Ben 實測通過，含數字直打）

**與設計文件 §2 掛鉤 C 的重大偏離（資料驅動，之後以本節為準）：**

1. **空白歧義判中文，不判英文**。設計文件的 Policy v0「模糊時判英文」只量了英文側（0.061%）；本次用 McBopomofo 詞頻資料補量中文側，「模糊判英文」會誤殺 **2.69% 的中文音節**（一=u 佔 1.4%、因=up 0.3%、詩=g、高=el、資=y……），因為 google-10000 詞典混入大量單字母與雜訊詞條（i/t/g/y/al/co/el…）。乘上 90:10 使用比，中文優先的總代價（≈0.19%）比英文優先（≈2.4%）低一個數量級。且「因」常出現在「因為」等詞中間被空白斷開，判英文會直接打斷組字。英文側真正的高頻犧牲者只有 so/go/no/uk——其中 no/uk 是罕見音節照判英文，so/go 的一聲 unigram 不存在、掛鉤 B 本來就會轉英文，**實際只剩 "up" 一個常用英文字預設輸給「因」**，靠 ↑ 切換兜底。
2. **切換鍵定案：↑（Up）**，不用 Tab。組字中 Tab 已是候選字循環、↓ 是開候選字視窗（空白定案後這功能必須保留），↑ 在橫排組字狀態原本就是被吸收的 no-op（`absorbedArrowKey`），是唯一免費的鍵。**pending token 的切換也從「↑↓ 皆可」改為只有 ↑**（一鍵一語意；↓ 恢復原版行為）。直排模式（useVerticalMode）↑ 是游標鍵，切換功能整個停用。

實作內容：

- **掛鉤 C**（KeyHandler.mm，composeReading 內 hasUnigrams 檢查之前）：空白/Enter 以一聲收尾 token 時，問分類器 `verdictForKeys:followedBySpace:YES`——english（罕見音節撞常用英文字如 "no"=ㄙㄟ、或音節表外鍵序如 "1"=單獨ㄅ）→ 轉英文（空白＝插字面空白繼續組字；Enter＝直接 commit）；chinese/ambiguous → 照常組字。附帶效益：`1`/`a`/`q` 等單獨聲母鍵+空白現在出字面（原版會出注音符號字典項 ㄅ…），打數字更順。
- **空白定案記錄 + ↑ 切換**：空白收尾的 token（不論判中判英）記下原始鍵序；緊接著按 ↑ 可在「一個組好的音節」↔「字面鍵+空白」之間來回切換（因↔up␣、㩙↔no␣、ㄅ↔1␣）。記錄在下一個非 ↑ 鍵、clear()、commit 時失效。判英文但注音側無 unigram（如 so/go/uk）沒有另一解讀，不設記錄。
- **tooltip 提示**：ambiguous 判中文時（如 up→因）與罕見音節判英文可切回時（如 no），組字區 tooltip 顯示「↑ 切換為「…」」；切換後顯示反向提示。字串 v1 直接寫中文，rebrand 時再進在地化。
- **Bridge**：`SmartClassifierBridge.verdict(forKeys:followedBySpace:)` 新入口，log 帶 `+ space` 標記。
- **數字直打修正**（Ben 實測回報 654321/34455 打不出來，當場修）：問題根源是掛鉤 A 對「token 開頭的聲調鍵（3/4/6/7）」一律跳過 smart 管線（原意是保護 Issue 753 改前字聲調）。改為**只在改聲調真的適用時才跳過**（`allowChangingPriorTone` 偏好開啟＋游標前是真實注音字；此偏好預設關）——其餘情況聲調鍵開頭的鍵序進分類器，判 english（聲調開頭不可能是注音）自動轉字面數字。`654321`、`34455`、`因為`後直接接`34455` 都能直打。**殘留限制**：開頭是 5/1/2/8/9/0（ㄓㄅㄉㄚㄞㄢ）的數字串仍中文優先——`54`→至（5 還 pending 時可按 ↑ 轉字面再續打）、`10`+空白→班（空白後按 ↑ 切成 `10 `）；這是真歧義（它們就是合法注音鍵序），v1 靠 ↑ 兜底。
- SmartSwitchKit 零改動（policy 在 IME 層），36 測試全過；fork debug build 成功並已裝機（`~/Library/Input Methods/McBopomofo.app`，IME 程序已結束、下次選用時以新版啟動）。
- **改動檔案**（vendor 分支 `smart-mixed-mode`）：KeyHandler.mm（掛鉤 C、空白定案記錄 ivars、↑ 切換、記錄失效點、聲調鍵開頭數字轉字面）、SmartClassifierBridge.swift（followedBySpace 入口）。
- policy 量測工具：臨時 scratch script（用 data/google-10000-english.txt + vendor data.txt 詞頻），結論已完整記錄於上，未進 repo。

**Ben 驗收清單**（開著 log：`/usr/bin/log stream --predicate "subsystem == 'org.openvanilla.inputmethod.McBopomofo' AND category == 'SmartSwitch'"`）：

1. `up`+空白 → 因 + tooltip；按 ↑ → `up `；再按 ↑ → 因。空白後按 ↓ 仍開候選字視窗（音/陰…）。
2. `no`+空白 → `no `（罕見音節判英文）+ tooltip；按 ↑ → 㩙。
3. `u`+空白 → 一（照常）；`t`+空白 → 吃；`el`+空白 → 高——**高頻中文不受影響**。
4. `so`+空白、`go`+空白 → 字面英文（掛鉤 B/C，無 ↑ 切換）。
5. `1`+空白 → `1 `（新行為）；按 ↑ → ㄅ（要打注音符號的後路）。
6. `因為`（u p 空白 w p 4）→ 照常組出因為；純中文長句無誤切；`hello` 自動轉英文照舊。
7. pending token（如單獨 `5`）只有 ↑ 能切 ㄓ↔5，↓ 不再切換。
8. `654321`、`34455`、`因為34455` → 數字直接出（聲調鍵開頭）；`54` 仍出 至、`10`+空白仍出 班（可 ↑ 切換）——這兩類是合法注音鍵序，屬預期行為。

## 掛鉤 A/B 完成（2026-08-03，第四次 session）

實作與設計文件 §2 有兩個重要偏離（都是降風險，之後讀設計文件要以本節為準）：

1. **token 生命週期＝未完成音節**：每完成一個音節（composeReading 成功）就重置 `_rawKeyBuffer`。轉換時所有鍵都還在 `_bpmfReadingBuffer`，**不需要回退 grid**——原設計的 `deleteReadingBeforeCursor` 回退路徑整個免掉。副作用：`classifyPrefix` 對「完成音節+英文尾」整串判 english 的語意問題也一併消失。
2. **沒有新增 `InputState.SmartEnglish`**：英文字以 LM 內建 reading 逐鍵插入 grid（`_letter_X`／`_numpad_N`／`_half_punctuation_*`）+ `overrideCandidate` 鎖定字元。顯示、Backspace、游標、Enter commit 全部沿用 Inputting 既有機制。

其他實作要點：

- **掛鉤 A**：BPMF 處理前，printable 鍵先進 `_rawKeyBuffer` 問分類器；impossible → 清 bpmf buffer、逐鍵插入字面 reading、`_smartTokenEnglish = YES`。僅限 Standard（大千）鍵盤配置 + 游標在行尾。token 鍵集合＝字母/數字/`,./;-`（其他標點不進 smart 管線，保持中文標點行為）。空白/3/4/6/7 在 token 開頭視為聲調鍵跳過（保護 Issue 753 前字改聲調功能）。
- **掛鉤 B**：composeReading 的 hasUnigrams 失敗 → 轉英文而非 beep（捕捉聲調層缺字，如 "no3"）。觸發鍵是空白→插入空白 reading 繼續組字；Enter→直接 commit。
- **英文 token 中的空白**：LM 對 `" "` reading 有特殊處理（McBopomofoLM.cpp:140），插入字面空白、組字繼續，Enter 才送出。
- **上下鍵切換解讀**（Ben 提的需求，當場加）：pending token 按 ↑/↓ 在注音↔字面鍵之間切換（`5`＝ㄓ↔5、`so`＝ㄋㄟ↔so）；已自動判英文的（鍵序非合法注音）不可切回。字面→注音的回退＝pop `_rawKeyBuffer.size()` 個 grid reading + 重餵 combineKey，這就是掛鉤 C 需要的雙向路徑。
- **資料陷阱（重要）**：`,` `.` `;` `/` `-` 的半形 reading 在 BPMFPunctuations.txt 以 **shift 字元**命名（`.` → `_half_punctuation_Standard_>`），通用 `_half_punctuation_<char>` 查找會落空導致轉換丟字（"x.com"→"xcom"），已用明確對應表修掉。
- **重置點**：clear()、composeReading 成功、Backspace（英文 token 逐鍵同步 pop）、Esc、左右/Home/End 游標移動、setInputMode。同步不變式：undecided token 時 rawKeys 與 bpmf buffer 鍵數 1:1（desync 時跳過 smart 自癒）。
- **開關**：`defaults write org.openvanilla.inputmethod.McBopomofo SmartMixedModeEnabled -bool true`（已開）。關掉即回到原版行為。
- 36 測試全過；Ben 實測：純中文長句無誤切、hello/大寫/x.com/Backspace 正常。
- **改動檔案**（vendor 分支 `smart-mixed-mode`）：KeyHandler.mm（ivars、掛鉤 A/B、切換、重置點）、Preferences.swift（smartMixedModeEnabled）、SmartClassifierBridge.swift（改寫為 @objc verdict API，observer 移除）、InputMethodController.swift（移除 log-only 呼叫）。

## Phase 2 步驟 1–2 完成（2026-08-03，第三次 session）

- **`parsePrefix` 增量 API**：`ZhuyinParser.parsePrefix` 逐鍵判斷 complete/prefix/impossible，靠新的 `SyllableTable.validPrefixes`（所有合法音節的前綴集合）在聲調鍵之前就能剔除不可能的鍵序（"hi"＝ㄘㄛ、"hel" 都在第二鍵判定英文）。`Classifier.classifyPrefix(keys:followedBySpace:)` 是掛鉤 A（逐鍵）與掛鉤 C（空白定案）的單一入口。
- **rareSyllables 降權已實作**：罕見音節撞常用英文字（"no"＝ㄙㄟ、"uk"＝ㄧㄜ）→ 判英文，但保留注音解讀（供之後 Tab 切換）。含明確聲調鍵（如 "no4"）不受影響照判中文。
- **測試 15 → 36 全過**；準確率重跑持平（整體 98.82%、英文側 Zipf 加權 0.061%）。
- **內建詞典**：`Sources/SmartSwitchKit/Resources/english-top3000.txt`（google-10000-english 前 3000，Policy v0 同規格）以 SPM resource 打包，`Lexicon.top3000` 載入。⚠️ google-10000-english 的資料授權不明確，Phase 4 公開前要確認或換來源（SCOWL）。
- **log-only bridge 已裝機驗證**：SmartSwitchKit 以 local package 掛進 fork（pbxproj 手動接線，package platforms 降到 macOS 12 配合部署目標）；`Source/SmartClassifierBridge.swift` 鏡射鍵序、逐鍵 log 判斷，不改任何行為；`InputMethodController.handle(event:)` 只加一行。Ben 實測：中文詞全判對、不合文法鍵序中途就標 english——管線驗證通過。
- **fork 修改保存**：vendor/McBopomofo 在本機分支 `smart-mixed-mode` commit（改了 pbxproj、InputMethodController.swift、新增 SmartClassifierBridge.swift）。vendor 仍 gitignored、無遠端；正式 fork repo 結構待掛鉤 A/B 穩定後再定。
- **除錯備忘**：Xcode 26 debug build 的主程式碼在 `Contents/MacOS/McBopomofo.debug.dylib`（主執行檔只是 stub），驗證符號要看 dylib。zsh 下 `log` 是內建指令，查系統 log 要用 `/usr/bin/log`。看判斷：`/usr/bin/log stream --predicate "subsystem == 'org.openvanilla.inputmethod.McBopomofo' AND category == 'SmartSwitch'"`。

## Phase 1 完成 + Phase 2 設計（2026-08-03，第二次 session）

- **安裝**：debug build（3.0/2264, arm64）已複製到 `~/Library/Input Methods/McBopomofo.app`。Ben 三月裝的官方版備份在 `backup/McBopomofo-official-replaced.app`（不進 git；要還原就搬回去）。Ben 日常用內建注音，McBopomofo 原本就未啟用，換版無日常影響。輸入法註冊（TISRegisterInputSource）AI 被權限系統擋，由 Ben 跑 `scripts/register_ime.swift` 完成 → 三個輸入來源全部註冊+啟用成功，**Ben 實測打字/選字/Backspace/Esc 正常**（2026-08-03）。
- **建置注意（新發現）**：`xcodebuild -scheme McBopomofo` 不可加 `SYMROOT=build` 覆寫——會弄壞 SPM 套件建置（SQLite 模組解析失敗）。用預設 DerivedData 即可，產物在 `~/Library/Developer/Xcode/DerivedData/McBopomofo-*/Build/Products/Debug/`。
- **音節表校正完成**：與 McBopomofo `BPMFBase.txt`+`BPMFMappings.txt`（429 音節）比對——手工表漏 9 個罕見音節（ㄧㄜ ㄧㄞ ㄅㄧㄤ ㄆㄧㄚ ㄈㄧㄠ ㄋㄨㄣ ㄌㄩㄢ ㄔㄨㄚ ㄙㄟ，已補）、多 3 個詞典沒有的（ㄉㄣ ㄌㄛ ㄎㄟ，已刪）；14 個「單獨聲母」項是注音符號本身的字典項，**刻意不收**（否則單一英文字母全變合法中文）。表格現在 415 音節、與詞典完全一致，比對工具在 `scripts/calibrate_syllables.py`（可重跑，OK/MISMATCH 收尾）。新增 `SyllableTable.rareSyllables`（9 個罕見音節，分類器降權用；注意 ㄙㄟ 鍵序＝"no"）。15 測試全過。
- **準確率重跑**（字表已改放 `data/`，gitignored）：整體 98.82%（90:10）、英文側 Zipf 加權誤判 0.061%——與校正前持平，罕見音節新增 "no"、"uk" 兩個衝突但可詞頻壓掉。
- **Phase 2 設計文件**：`docs/smart-mixed-mode-design.md`——KeyHandler 三個掛鉤點（BPMF 鍵前分類、hasUnigrams 失敗＝英文訊號、空白歧義決策）、`_rawKeyBuffer`、`SmartClassifierBridge`、新狀態 `InputState.SmartEnglish`、五步實作順序（先 log-only 驗證再動行為）。

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
