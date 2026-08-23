import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "BarWidgetModel.js" as Model

Panel {
  id: root
  moduleName: "tobiasz-p.market-tracker"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.barForeground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool configured:  hostWidget ? hostWidget.configured  : false
  readonly property bool daemonReady: hostWidget ? hostWidget.daemonReady : false
  readonly property bool fetching:    hostWidget ? hostWidget.fetching    : false
  readonly property string lastError: hostWidget ? hostWidget.lastError   : ""
  readonly property var symbolList:   hostWidget ? hostWidget.symbolList  : []
  readonly property var quotes:       hostWidget ? hostWidget.quotes      : ({})
  readonly property bool stealthMode: hostWidget ? hostWidget.stealthMode : false

  property var profileData: ({})
  property var recsData: ({})
  property var newsData: ({})
  property string activeSymbol: ""
  property int activeIndex: 0

  function open()  { reload(); root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function reload() {
    quoteRepeater.model = root.symbolList.slice()
    if (!activeSymbol && root.symbolList.length > 0) {
      activeIndex = 0
      requestDetail(root.symbolList[0])
    }
  }
  function refresh() { if (root.hostWidget) root.hostWidget.forceRefresh() }

  function handleDaemonData(data) {
    if (!data) return
    var dataSym = String(data.symbol || "").toUpperCase()
    var curSym  = String(activeSymbol || "").toUpperCase()
    if (dataSym && curSym && dataSym !== curSym) return

    if (data.type === "profile") profileData = data
    else if (data.type === "recommendations") recsData = data
    else if (data.type === "news") newsData = data
  }

  function requestDetail(symbol) {
    var sym = String(symbol || "").toUpperCase()
    if (!sym) return
    activeSymbol = sym
    profileData = ({})
    recsData = ({})
    newsData = ({})
    if (root.hostWidget) {
      root.hostWidget.fetchDetail(sym)
    }
  }

  function googleFinanceUrl(sym) {
    if (!sym) return "https://www.google.com/finance"
    var ex = String((profileData ? profileData.exchange : "") || "").toUpperCase()
    var gEx = ""
    if (ex.indexOf("NASDAQ") !== -1 || ex === "NGM" || ex === "NMS" || ex === "NCM") gEx = "NASDAQ"
    else if (ex.indexOf("ARCA") !== -1 || ex === "PCX" || ex === "PSE") gEx = "NYSEARCA"
    else if (ex.indexOf("NEW YORK") !== -1 || ex.indexOf("NYSE") !== -1 || ex === "NYQ") gEx = "NYSE"
    else if (ex.indexOf("BATS") !== -1 || ex.indexOf("CBOE") !== -1 || ex === "BTS") gEx = "BATS"
    else if (ex.indexOf("AMEX") !== -1 || ex === "ASE") gEx = "AMEX"
    else if (ex.indexOf("INDEX") !== -1) gEx = "INDEXSP"

    if (gEx) return "https://www.google.com/finance/quote/" + encodeURIComponent(sym) + ":" + gEx
    return "https://www.google.com/finance/quote/" + encodeURIComponent(sym)
  }

  readonly property var portfolioSummary: {
    var totalVal = 0
    var totalChg = 0
    var hasHoldings = false
    var items = []
    for (var i = 0; i < symbolList.length; i++) {
      var sym = symbolList[i]
      var q = quotes[sym]
      if (q && q.shares && q.shares > 0) {
        hasHoldings = true
        var val = q.portfolioValue || 0
        var chg = q.portfolioChange || 0
        totalVal += val
        totalChg += chg
        items.push({ symbol: sym, shares: q.shares, value: val, change: chg, price: q.price })
      }
    }
    if (!hasHoldings) return null
    for (var j = 0; j < items.length; j++) {
      items[j].pct = totalVal > 0 ? (items[j].value / totalVal) * 100 : 0
    }
    return {
      totalValue: totalVal,
      totalChange: totalChg,
      totalChangePct: (totalVal - totalChg) > 0 ? (totalChg / (totalVal - totalChg)) * 100 : 0,
      items: items
    }
  }

  readonly property var activeQuote: activeSymbol ? (quotes[activeSymbol] || null) : null

  onHostWidgetChanged: Qt.callLater(root.reload)
  onOpenedChanged: if (opened) root.reload()
  Connections { target: root.hostWidget; function onDataChanged() { root.reload() } }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: scroll.width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: scroll.width
          spacing: Style.space(14)

          // Header
          Item {
            width: parent.width
            height: Math.max(headingRow.height, refreshBtn.height)

            RowLayout {
              id: headingRow
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Text {
                text: "MARKET TRACKER"
                color: Qt.darker(root.contentForeground, 1.3)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1.2
                font.bold: true
              }
            }

            PanelActionButton {
              id: refreshBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: ""
              tooltipText: root.fetching ? "Updating..." : "Refresh quotes"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: !root.fetching && root.configured
              opacity: (root.fetching || !root.configured) ? 0.5 : 1.0
              onClicked: root.refresh()
            }
          }

          // Unconfigured warning
          Item {
            visible: !root.configured
            width: parent.width
            height: visible ? setupCol.implicitHeight : 0
            Column {
              id: setupCol
              width: parent.width
              spacing: Style.space(8)
              Text {
                width: parent.width
                text: "No symbols configured"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
              Text {
                width: parent.width
                text: "Run in your terminal:\nomarchy bar set tobiasz-p.market-tracker symbols SPY,QQQ,AAPL"
                color: Qt.darker(root.contentForeground, 1.35)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          // Portfolio Summary & Allocation Card (when user configured shares)
          Item {
            visible: portfolioSummary !== null
            width: parent.width
            height: visible ? portCard.implicitHeight : 0

            Rectangle {
              id: portCard
              width: parent.width
              height: portCol.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: Style.normalFillFor(root.contentForeground, Color.accent)
              border.color: Qt.darker(root.contentForeground, 1.7)
              border.width: 1

              Column {
                id: portCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                RowLayout {
                  width: parent.width
                  Column {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                      text: "PORTFOLIO TOTAL"
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                      font.bold: true
                    }
                    Text {
                      text: portfolioSummary ? (root.stealthMode ? "$••••••" : "$" + portfolioSummary.totalValue.toFixed(2)) : "$0.00"
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: 16
                      font.bold: true
                    }
                  }

                  Rectangle {
                    height: 22
                    width: portPnlText.implicitWidth + 12
                    radius: 4
                    color: portfolioSummary && portfolioSummary.totalChange >= 0 ? "rgba(34,197,94,0.18)" : "rgba(239,68,68,0.18)"
                    Text {
                      id: portPnlText
                      anchors.centerIn: parent
                      text: {
                        if (!portfolioSummary) return ""
                        var sign = portfolioSummary.totalChange >= 0 ? "+" : ""
                        var delta = root.stealthMode ? "$••••" : "$" + portfolioSummary.totalChange.toFixed(2)
                        return sign + delta + " (" + sign + portfolioSummary.totalChangePct.toFixed(2) + "%)"
                      }
                      color: portfolioSummary && portfolioSummary.totalChange >= 0 ? "#22c55e" : "#ef4444"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }

                // Proportional allocation bar
                Row {
                  width: parent.width
                  height: 8
                  spacing: 2
                  clip: true

                  Repeater {
                    model: portfolioSummary ? portfolioSummary.items : []
                    delegate: Rectangle {
                      width: Math.max(2, (parent.width - ((portfolioSummary.items.length - 1) * 2)) * (modelData.pct / 100))
                      height: parent.height
                      radius: 2
                      color: ["#6366f1", "#22c55e", "#eab308", "#38bdf8", "#ec4899", "#a855f7"][index % 6]
                    }
                  }
                }

                // Allocation legend
                RowLayout {
                  width: parent.width
                  spacing: Style.space(8)

                  Repeater {
                    model: portfolioSummary ? portfolioSummary.items : []
                    delegate: RowLayout {
                      spacing: 4
                      Rectangle {
                        width: 8
                        height: 8
                        radius: 2
                        color: ["#6366f1", "#22c55e", "#eab308", "#38bdf8", "#ec4899", "#a855f7"][index % 6]
                      }
                      Text {
                        text: modelData.symbol + " " + modelData.pct.toFixed(0) + "%"
                        color: Qt.darker(root.contentForeground, 1.4)
                        font.family: root.contentFontFamily
                        font.pixelSize: 10
                      }
                    }
                  }
                }
              }
            }
          }

          // Watchlist Cards
          Column {
            width: parent.width
            spacing: Style.space(8)

            Repeater {
              id: quoteRepeater
              model: root.symbolList
              delegate: Item {
                width: parent.width
                height: cardCol.implicitHeight + Style.space(16)
                readonly property string sym: modelData
                readonly property var quote: root.quotes[sym] || null
                readonly property bool isSelected: root.activeSymbol === sym
                readonly property bool pos: quote ? (quote.change || 0) >= 0 : true
                readonly property color trendColor: pos ? "#22c55e" : "#ef4444"

                Rectangle {
                  id: cardBg
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: isSelected
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
                    : (cardMouse.containsMouse ? Qt.lighter(Style.normalFillFor(root.contentForeground, Color.accent), 1.08) : Style.normalFillFor(root.contentForeground, Color.accent))
                  border.color: isSelected ? Color.accent : (cardMouse.containsMouse ? Qt.darker(root.contentForeground, 1.7) : "transparent")
                  border.width: isSelected ? 1.5 : 1

                  Behavior on border.color { ColorAnimation { duration: 150 } }
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Active Left Accent Strip
                Rectangle {
                  id: activeStrip
                  visible: isSelected
                  width: 3.5
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.margins: 2
                  radius: 2
                  color: Color.accent
                }

                MouseArea {
                  id: cardMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeIndex = index
                    root.requestDetail(sym)
                  }
                }

                Column {
                  id: cardCol
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.space(10)
                  spacing: Style.space(6)

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(8)

                    Column {
                      Layout.fillWidth: true
                      spacing: 2
                      RowLayout {
                        spacing: Style.space(6)
                        Text {
                          text: sym
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: 14
                          font.bold: true
                        }
                        Rectangle {
                          visible: isSelected
                          width: 6
                          height: 6
                          radius: 3
                          color: Color.accent
                        }
                      }
                      Text {
                        width: parent.width
                        text: quote ? (quote.name || sym) : "Loading..."
                        color: Qt.darker(root.contentForeground, 1.45)
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                      }
                    }

                    Column {
                      spacing: 2
                      Text {
                        anchors.right: parent.right
                        text: quote ? (quote.priceFmt || "---") : "---"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: 14
                        font.bold: true
                      }
                      Rectangle {
                        anchors.right: parent.right
                        height: 18
                        width: changeLabel.implicitWidth + 10
                        radius: 4
                        color: pos ? "rgba(34,197,94,0.18)" : "rgba(239,68,68,0.18)"
                        Text {
                          id: changeLabel
                          anchors.centerIn: parent
                          text: (pos ? "▲ " : "▼ ") + (quote ? (quote.changeFmt || "0.00%") : "---")
                          color: trendColor
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }
                      }
                    }
                  }

                  Canvas {
                    id: cardSparkline
                    width: parent.width
                    height: 32
                    visible: quote && Array.isArray(quote.sparkline) && quote.sparkline.length >= 2
                    readonly property var sparkData: quote ? (quote.sparkline || []) : []
                    onSparkDataChanged: requestPaint()
                    onPaint: {
                      var ctx = getContext("2d")
                      ctx.clearRect(0, 0, width, height)
                      var pts = Model.sparklinePoints(sparkData, width, height, 4, 4)
                      if (pts.length < 2) return
                      var lc = pos ? "#22c55e" : "#ef4444"
                      ctx.beginPath()
                      ctx.moveTo(pts[0].x, pts[0].y)
                      for (var i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x, pts[i].y)
                      ctx.lineTo(pts[pts.length - 1].x, height)
                      ctx.lineTo(pts[0].x, height)
                      ctx.closePath()
                      var g = ctx.createLinearGradient(0, 0, 0, height)
                      g.addColorStop(0, pos ? "rgba(34,197,94,0.22)" : "rgba(239,68,68,0.22)")
                      g.addColorStop(1, "rgba(0,0,0,0)")
                      ctx.fillStyle = g
                      ctx.fill()

                      ctx.beginPath()
                      ctx.moveTo(pts[0].x, pts[0].y)
                      for (var j = 1; j < pts.length; j++) ctx.lineTo(pts[j].x, pts[j].y)
                      ctx.strokeStyle = lc
                      ctx.lineWidth = 1.6
                      ctx.lineJoin = "round"
                      ctx.lineCap = "round"
                      ctx.stroke()
                    }
                  }

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                      text: "Prev: " + (quote && quote.prevClose ? "$" + quote.prevClose.toFixed(2) : "---")
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }

                    Text {
                      visible: quote && quote.dayHigh && quote.dayLow
                      text: "Day: $" + (quote && quote.dayLow ? quote.dayLow.toFixed(2) : "") + " – $" + (quote && quote.dayHigh ? quote.dayHigh.toFixed(2) : "")
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                      text: isSelected ? "Active ▾" : "Details ▸"
                      color: isSelected ? Color.accent : Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: isSelected
                    }
                  }

                  RowLayout {
                    width: parent.width
                    visible: quote && quote.shares && quote.shares > 0
                    spacing: Style.space(8)
                    Text {
                      text: quote && quote.shares ? (root.stealthMode ? "•• sh" : quote.shares.toFixed(1) + " sh") : ""
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }
                    Text {
                      text: quote && quote.portfolioValue ? (root.stealthMode ? "Val: $••••" : "Val: $" + quote.portfolioValue.toFixed(2)) : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Text {
                      text: {
                        if (!quote || quote.portfolioChange === undefined || quote.portfolioChange === null) return ""
                        var sign = quote.portfolioChange >= 0 ? "+" : ""
                        var chg = root.stealthMode ? "$••••" : "$" + quote.portfolioChange.toFixed(2)
                        return sign + chg
                      }
                      color: quote && quote.portfolioChange >= 0 ? "#22c55e" : "#ef4444"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }
                }
              }
            }
          }

          // Active Detail Section
          Item {
            visible: activeSymbol.length > 0
            width: parent.width
            height: visible ? detailCol.implicitHeight : 0

            Column {
              id: detailCol
              width: parent.width
              spacing: Style.space(12)

              Rectangle {
                width: parent.width
                height: 1
                color: Qt.darker(root.contentForeground, 1.8)
              }

              // Detail Header
              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Column {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    text: activeSymbol + " Overview"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    text: profileData.name || (activeQuote ? activeQuote.name : activeSymbol)
                    color: Qt.darker(root.contentForeground, 1.4)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                // Price and Delta badge in header
                Column {
                  spacing: 2
                  Text {
                    anchors.right: parent.right
                    text: activeQuote ? activeQuote.priceFmt : ""
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }
                  Text {
                    anchors.right: parent.right
                    text: activeQuote ? activeQuote.changeFmt : ""
                    color: activeQuote && activeQuote.positive ? "#22c55e" : "#ef4444"
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }
              }

              // 52-Week Range Visual Bullet Slider
              Item {
                id: rangeItem
                width: parent.width
                height: visible ? rangeCol.implicitHeight : 0
                visible: profileData.high52 && profileData.low52 && profileData.high52 > profileData.low52
                readonly property real curP: activeQuote ? activeQuote.price : (profileData.low52 || 0)
                readonly property real pctPos: Math.max(0, Math.min(1, (curP - profileData.low52) / (profileData.high52 - profileData.low52)))

                Column {
                  id: rangeCol
                  width: parent.width
                  spacing: Style.space(6)

                  RowLayout {
                    width: parent.width
                    Text {
                      text: "52W Range"
                      color: Qt.darker(root.contentForeground, 1.4)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                      text: "$" + rangeItem.curP.toFixed(2) + " (" + (rangeItem.pctPos * 100).toFixed(0) + "%)"
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                      visible: profileData.return52 !== undefined && profileData.return52 !== null
                      text: "52W: " + (profileData.return52 >= 0 ? "+" : "") + profileData.return52 + "%"
                      color: (profileData.return52 >= 0) ? "#22c55e" : "#ef4444"
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Bullet Track & Current Price Pin
                  Item {
                    width: parent.width
                    height: 14

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: parent.width
                      height: 6
                      radius: 3
                      color: Qt.darker(root.contentForeground, 1.8)

                      Rectangle {
                        width: parent.width * rangeItem.pctPos
                        height: parent.height
                        radius: 3
                        color: Color.accent
                        opacity: 0.85
                      }
                    }

                    // Current price bullet pin
                    Rectangle {
                      x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * rangeItem.pctPos))
                      anchors.verticalCenter: parent.verticalCenter
                      width: 5
                      height: 14
                      radius: 2.5
                      color: Color.accent
                      border.color: "white"
                      border.width: 1

                      Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                    }
                  }

                  RowLayout {
                    width: parent.width
                    Text {
                      text: "$" + (profileData.low52 ? profileData.low52.toFixed(2) : "---")
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                      text: "$" + (profileData.high52 ? profileData.high52.toFixed(2) : "---")
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                  }
                }
              }

              // Financial Metrics 2x2 Grid
              GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(8)

                Rectangle {
                  Layout.fillWidth: true
                  height: 48
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "10D Avg Vol"
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: profileData.avgVol ? profileData.avgVol + "M" : (activeQuote && activeQuote.volumeFmt ? activeQuote.volumeFmt : "---")
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 48
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: profileData.peTTM ? "P/E Ratio" : "Beta"
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: profileData.peTTM ? String(profileData.peTTM) : (profileData.beta ? String(profileData.beta) : "---")
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 48
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: profileData.marketCapFmt && profileData.marketCapFmt !== "—" ? "Market Cap" : "Asset Class"
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: profileData.marketCapFmt && profileData.marketCapFmt !== "—" ? profileData.marketCapFmt : (profileData.industry || "ETF / Fund")
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 48
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "Exchange / Currency"
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: (profileData.exchange ? profileData.exchange + " " : "") + (profileData.currency || "USD")
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: true
                      elide: Text.ElideRight
                    }
                  }
                }
              }

              // Analyst Recommendations Card (when available)
              Item {
                id: recsItem
                visible: recsData.type === "recommendations" && recsData.bar && recsData.bar.total > 0
                width: parent.width
                height: visible ? (recsCol.implicitHeight + Style.space(20)) : 0

                Rectangle {
                  id: recsCard
                  anchors.fill: parent
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)

                  Column {
                    id: recsCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.space(10)
                    spacing: Style.space(6)

                    RowLayout {
                      width: parent.width
                      Text {
                        text: "Analyst Consensus"
                        color: root.contentForeground
                        font.family: root.contentFontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                      Item { Layout.fillWidth: true }
                      Rectangle {
                        visible: !!(recsData && recsData.consensusLabel)
                        height: 18
                        width: cLabel.implicitWidth + 10
                        radius: 4
                        color: Color.accent
                        Text {
                          id: cLabel
                          anchors.centerIn: parent
                          text: recsData.consensusLabel || ""
                          color: "white"
                          font.family: root.contentFontFamily
                          font.pixelSize: 10
                          font.bold: true
                        }
                      }
                    }

                    // Distribution bar
                    Item {
                      width: parent.width
                      height: 12

                      Row {
                        anchors.fill: parent
                        spacing: 0
                        Rectangle { width: parent.width * ((recsData.bar ? recsData.bar.pct_strongBuy : 0) / 100); height: parent.height; color: "#22c55e"; radius: 2 }
                        Rectangle { width: parent.width * ((recsData.bar ? recsData.bar.pct_buy : 0) / 100); height: parent.height; color: "#86efac" }
                        Rectangle { width: parent.width * ((recsData.bar ? recsData.bar.pct_hold : 0) / 100); height: parent.height; color: "#eab308" }
                        Rectangle { width: parent.width * ((recsData.bar ? recsData.bar.pct_sell : 0) / 100); height: parent.height; color: "#fca5a5" }
                        Rectangle { width: parent.width * ((recsData.bar ? recsData.bar.pct_strongSell : 0) / 100); height: parent.height; color: "#ef4444"; radius: 2 }
                      }
                    }

                    RowLayout {
                      width: parent.width
                      Repeater {
                        model: ["Strong Buy", "Buy", "Hold", "Sell", "Strong Sell"]
                        delegate: Text {
                          Layout.fillWidth: true
                          text: modelData
                          horizontalAlignment: Text.AlignHCenter
                          color: Qt.darker(root.contentForeground, 1.5)
                          font.family: root.contentFontFamily
                          font.pixelSize: 8
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      text: "Aggregated 3rd-party analyst ratings via Finnhub. For informational purposes only; not investment advice."
                      wrapMode: Text.WordWrap
                      color: Qt.darker(root.contentForeground, 1.8)
                      font.family: root.contentFontFamily
                      font.pixelSize: 8
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }
                }
              }

              // Recent News Feed
              Item {
                visible: newsData.type === "news" && newsData.headlines && newsData.headlines.length > 0
                width: parent.width
                height: visible ? newsCol.implicitHeight : 0

                Column {
                  id: newsCol
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "Recent News"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }

                  Repeater {
                    model: (newsData.headlines || []).slice(0, 4)
                    delegate: Rectangle {
                      width: parent.width
                      height: nCol.implicitHeight + Style.space(12)
                      radius: Style.cornerRadius
                      color: nMouse.containsMouse ? Qt.lighter(Style.normalFillFor(root.contentForeground, Color.accent), 1.1) : Style.normalFillFor(root.contentForeground, Color.accent)

                      MouseArea {
                        id: nMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (root.bar && modelData.url) root.bar.run("xdg-open " + Util.shellQuote(modelData.url))
                        }
                      }

                      Column {
                        id: nCol
                        anchors.fill: parent
                        anchors.margins: Style.space(8)
                        spacing: 4

                        Text {
                          width: parent.width
                          text: modelData.headline || ""
                          wrapMode: Text.WordWrap
                          maximumLineCount: 2
                          elide: Text.ElideRight
                          color: root.contentForeground
                          font.family: root.contentFontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        RowLayout {
                          width: parent.width
                          spacing: Style.space(6)
                          Text {
                            text: modelData.source || "News"
                            color: Color.accent
                            font.family: root.contentFontFamily
                            font.pixelSize: 9
                            font.bold: true
                          }
                          Text {
                            text: "• " + Model.timeAgo(modelData.datetime)
                            color: Qt.darker(root.contentForeground, 1.5)
                            font.family: root.contentFontFamily
                            font.pixelSize: 9
                          }
                          Item { Layout.fillWidth: true }
                          Text {
                            text: "Open ↗"
                            color: Color.accent
                            font.family: root.contentFontFamily
                            font.pixelSize: 9
                          }
                        }
                      }
                    }
                  }
                }
              }

              // Footer Quick Links
              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                Rectangle {
                  Layout.fillWidth: true
                  height: 30
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  border.color: gfMouse.containsMouse ? Color.accent : "transparent"
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "Google Finance ↗"
                      color: Color.accent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: gfMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.bar) root.bar.run("xdg-open " + Util.shellQuote(root.googleFinanceUrl(activeSymbol)))
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 30
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  border.color: yfMouse.containsMouse ? Color.accent : "transparent"
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "Yahoo Finance ↗"
                      color: Color.accent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: yfMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.bar) root.bar.run("xdg-open " + Util.shellQuote("https://finance.yahoo.com/quote/" + activeSymbol))
                    }
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 30
                  radius: Style.cornerRadius
                  color: Style.normalFillFor(root.contentForeground, Color.accent)
                  border.color: tvMouse.containsMouse ? Color.accent : "transparent"
                  border.width: 1

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      text: "TradingView ↗"
                      color: Color.accent
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: tvMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      if (root.bar) root.bar.run("xdg-open " + Util.shellQuote("https://www.tradingview.com/symbols/" + activeSymbol))
                    }
                  }
                }
              }

              // Informational & Legal Disclaimer
              Text {
                width: parent.width
                text: "Market data & indicators provided for informational purposes only; not financial or investment advice."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: 8
              }
            }
          }

          Item { width: 1; height: Style.space(4) }
        }
      }
    }
  }
}
