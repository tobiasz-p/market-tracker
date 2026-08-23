import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "tobiasz-p.market-tracker"

  readonly property string symbolsSetting: String(setting("symbols", "") || "").trim()
  readonly property string apiKeySetting: {
    var fromEnv = (Quickshell.env("FINNHUB_API_KEY") || "").trim()
    if (fromEnv.length > 0) return fromEnv
    if (envFileKey.length > 0) return envFileKey
    return String(setting("apiKey", "") || "").trim()
  }
  readonly property int refreshSeconds: Math.max(15, parseInt(setting("refreshSeconds", 60), 10) || 60)
  readonly property int rotateSeconds:  Math.max(0,  parseInt(setting("rotateSeconds",   5), 10) || 5)
  readonly property bool showPrice: parseBool(setting("showPrice", true), true)
  readonly property string deltaFormat: {
    var v = String(setting("deltaFormat", "percent") || "percent").toLowerCase()
    return (v === "amount" || v === "both") ? v : "percent"
  }
  readonly property bool showCompanyProfile: parseBool(setting("showCompanyProfile", true), true)
  readonly property bool showRecommendations: parseBool(setting("showRecommendations", true), true)
  readonly property bool showNews: parseBool(setting("showNews", true), true)
  readonly property bool stealthMode: parseBool(setting("stealthMode", false), false)

  function parseBool(v, def) {
    if (v === true || v === 1 || v === "1" || v === "true") return true
    if (v === false || v === 0 || v === "0" || v === "false") return false
    return (v === undefined || v === null) ? def : String(v).toLowerCase() !== "false"
  }

  property var   quotes:       ({})
  property var   symbolList:   []
  property int   currentIndex: 0
  property bool  daemonReady:  false
  property bool  fetching:     false
  property string lastError:   ""

  readonly property var currentQuote: {
    if (symbolList.length === 0) return null
    var sym = symbolList[currentIndex % symbolList.length]
    return quotes[sym] || null
  }
  readonly property bool configured: symbolList.length > 0
  readonly property bool hasApiKey:  apiKeySetting.length > 0

  readonly property string daemonSignature: [
    symbolsSetting, apiKeySetting, refreshSeconds, rotateSeconds,
    deltaFormat, showPrice,
    showCompanyProfile, showRecommendations,
    showNews, stealthMode
  ].join("\n")

  readonly property string daemonPath:
    Quickshell.env("HOME") + "/.config/omarchy/plugins/tobiasz-p.market-tracker/daemon/fetcher.rb"

  function sendCommand(obj) {
    if (fetchProc.running) fetchProc.write(JSON.stringify(obj) + "\n")
  }
  function forceRefresh() { sendCommand({ action: "refresh" }); root.fetching = true }
  function nextSymbol() { if (symbolList.length > 1) root.currentIndex = (root.currentIndex + 1) % symbolList.length }
  function fetchDetail(symbol) { sendCommand({ action: "fetch_detail", symbol: symbol }) }

  function parseDotEnv(text) {
    var lines = String(text || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (!line || line.charAt(0) === "#") continue
      var eq = line.indexOf("=")
      if (eq <= 0) continue
      if (line.slice(0, eq).trim() !== "FINNHUB_API_KEY") continue
      var v = line.slice(eq + 1).trim()
      var n = v.length
      if (n >= 2 && ((v.charAt(0) === '"' && v.charAt(n - 1) === '"') ||
                     (v.charAt(0) === "'" && v.charAt(n - 1) === "'")))
        v = v.slice(1, -1)
      return v.trim()
    }
    return ""
  }

  FileView {
    id: dotEnvFile
    path: Qt.resolvedUrl(".env")
    blockLoading: true
    watchChanges: true
    printErrors: false
    onLoaded: root.envFileKey = root.parseDotEnv(dotEnvFile.text)
    onFileChanged: root.envFileKey = root.parseDotEnv(dotEnvFile.text)
  }
  property string envFileKey: ""

  function handleLine(raw) {
    var line = String(raw || "").trim()
    if (!line) return
    try {
      var data = JSON.parse(line)
      if (data.type === "ready") { root.daemonReady = true; return }
      if (data.type === "quote") {
        root.fetching = false
        var sym = String(data.symbol || "")
        if (!sym) return
        var updated = Object.assign({}, root.quotes)
        updated[sym] = data
        root.quotes = updated
        root.dataChanged()
        return
      }
      if (data.type === "profile" || data.type === "recommendations" || data.type === "news") {
        if (panelLoader.item) panelLoader.item.handleDaemonData(data)
        return
      }
      if (data.type === "error") {
        root.fetching = false
        var errSym = String(data.symbol || "*")
        root.lastError = (errSym !== "*" ? errSym + ": " : "") + String(data.message || "unknown error")
        root.dataChanged()
      }
    } catch (e) {}
  }

  function parseSymbolList(raw) {
    return String(raw || "").split(",").map(function(s) {
      var parts = s.trim().split(":")
      if (parts.length >= 2 && !isNaN(parseFloat(parts[parts.length - 1])) && isFinite(parts[parts.length - 1])) {
        parts.pop()
      }
      return parts.join(":").trim().toUpperCase()
    }).filter(function(s) { return s.length > 0 })
  }

  signal dataChanged()

  onDaemonSignatureChanged: {
    var syms = parseSymbolList(symbolsSetting)
    root.symbolList = syms; root.currentIndex = 0; root.quotes = ({}); root.daemonReady = false
    root.fetching = false; root.lastError = ""
    if (fetchProc.running) fetchProc.running = false
    if (syms.length > 0) daemonStartTimer.restart()
  }

  Component.onCompleted: {
    if (root.symbolList.length === 0 && symbolsSetting.length > 0)
      root.symbolList = parseSymbolList(symbolsSetting)
    if (root.symbolList.length > 0 && !fetchProc.running) daemonStartTimer.restart()
  }

  Timer { id: daemonStartTimer; interval: 300; repeat: false
    onTriggered: { if (root.symbolList.length > 0 && !fetchProc.running) { fetchProc.running = true; root.fetching = true } } }
  Timer { id: rotateTimer; interval: root.rotateSeconds > 0 ? root.rotateSeconds * 1000 : 60000
    running: root.symbolList.length > 1 && root.rotateSeconds > 0; repeat: true; onTriggered: root.nextSymbol() }
  Timer { id: restartTimer; interval: 5000; repeat: false
    onTriggered: { if (root.symbolList.length > 0 && !fetchProc.running) { root.daemonReady = false; fetchProc.running = true; root.fetching = true } } }

  Process {
    id: fetchProc
    command: ["ruby", root.daemonPath]
    environment: ({
      SYMBOLS: root.symbolsSetting, REFRESH_SECONDS: String(root.refreshSeconds),
      ROTATE_SECONDS: String(root.rotateSeconds), SHOW_PRICE: String(root.showPrice),
      DELTA_FORMAT: root.deltaFormat,
      SHOW_COMPANY_PROFILE: String(root.showCompanyProfile), SHOW_RECOMMENDATIONS: String(root.showRecommendations),
      SHOW_NEWS: String(root.showNews),
      STEALTH_MODE: String(root.stealthMode)
    })
    running: false; stdinEnabled: true
    stdout: SplitParser { onRead: function(line) { root.handleLine(line) } }
    onExited: function(exitCode) { root.fetching = false; root.daemonReady = false; restartTimer.start() }
  }

  onBarChanged: { injectPanel(); if (root.symbolList.length > 0 && !fetchProc.running) daemonStartTimer.restart() }
  onSettingsChanged: injectPanel()
  onDataChanged: { if (panelLoader.item) panelLoader.item.reload() }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()  { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }

  function injectPanel() {
    var t = panelLoader.item; if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("settings" in t) t.settings = root.settings
    if ("anchorItem" in t) t.anchorItem = btn
    if ("hostWidget" in t) t.hostWidget = root
  }

  Loader { id: panelLoader; active: true; source: Qt.resolvedUrl("Panel.qml"); visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) } }

  implicitWidth: btn.implicitWidth; implicitHeight: btn.implicitHeight

  WidgetButton {
    id: btn; anchors.fill: parent; bar: root.bar
    text: {
      if (!root.configured) return "\u{F0247}"
      if (!root.daemonReady && !root.currentQuote) return "\u{F0247}"
      return root.currentQuote ? root.currentQuote.barLabel : ""
    }
    labelVisible: true; hasVisualContent: true
    dimmed: !root.configured || (!root.daemonReady && !root.currentQuote)
    active: false; useActiveColor: false; horizontalMargin: 8; verticalPadding: 6
    tooltipText: {
      if (root.currentQuote) return root.currentQuote.tooltip
      if (!root.configured) return "Market Tracker - Set symbols:\nomarchy bar set tobiasz-p.market-tracker symbols VOO,QQQ"
      return root.lastError !== "" ? "Error: " + root.lastError : "Fetching data..."
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) root.forceRefresh()
      else if (b === Qt.MiddleButton) root.nextSymbol()
      else root.toggle()
    }

    Rectangle {
      id: trendUnderline
      visible: root.currentQuote !== null && root.currentQuote !== undefined && root.configured
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 6
      anchors.rightMargin: 6
      anchors.bottomMargin: 1
      height: 2
      radius: 1
      color: (root.currentQuote && (root.currentQuote.change || 0) >= 0) ? "#22c55e" : "#ef4444"
      opacity: 0.85

      Behavior on color { ColorAnimation { duration: 250 } }
    }
  }
}
