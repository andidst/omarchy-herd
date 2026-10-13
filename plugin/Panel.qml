import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "andidst.herd"
  ipcTarget: "andidst.herd"
  manageIpc: false

  // Where the bar icon and panel get their data. To work on the layout
  // without a running Herd, use the fixture instead:
  //   "cat ~/Work/omarchy-herd/plugin/sample-status.json"
  property string statusCommand: "omarchy-herd status --json"

  readonly property string glyph: "󰟆"
  property bool cursorActive: false
  property int cursorIndex: 0
  // Replaced by the theme's green from colors.toml (see themeColors below).
  property color okColor: Color.foreground

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool hasStatus: herd.status !== null
  readonly property int serviceCount: hasStatus ? herd.services.length : 0
  readonly property int rowCount: hasStatus ? serviceCount + herd.sites.length : 0
  readonly property real sitesMaxHeight: Math.max(Style.space(96), Math.min(Style.space(236),
    panel.availableCardHeight - panel.verticalContentInset - topBlock.implicitHeight
      - bottomBlock.implicitHeight - column.spacing * 2))

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
  }

  function moveCursor(dy) {
    if (rowCount === 0) return
    cursorIndex = Math.max(0, Math.min(rowCount - 1, cursorIndex + dy))
    if (cursorIndex >= serviceCount) sitesView.positionViewAtIndex(cursorIndex - serviceCount, ListView.Contain)
  }

  function activateCursor() {
    if (cursorIndex < serviceCount) herd.toggleService(herd.services[cursorIndex])
    else openSite(herd.sites[cursorIndex - serviceCount])
  }

  function openSite(site) {
    if (!site) return
    herd.openUrl(site.url || ("https://" + Model.siteDomain(site)))
    close()
  }

  function openDashboard() {
    herd.openUrl(herd.dashboardUrl)
    close()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = 0
    sitesView.positionViewAtBeginning()
    themeColors.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onRowCountChanged: if (cursorIndex >= rowCount) cursorIndex = Math.max(0, rowCount - 1)

  Service {
    id: herd
    statusCommand: root.statusCommand
    panelOpen: root.opened
    idleIntervalSec: Math.max(10, parseInt(root.setting("refreshIntervalSec", 30), 10) || 30)
  }

  Connections {
    target: herd
    function onActionFailed(message) {
      if (!root.opened) Quickshell.execDetached(["omarchy-notification-send", "-g", root.glyph, "Herd", message])
    }
  }

  FileView {
    id: themeColors
    path: Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.okColor = Model.themeGreen(text(), Color.foreground)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { herd.refresh(true); return "ok" }
    function status(): string { return herd.tooltip }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.glyph
    active: herd.loaded && !herd.healthy
    tooltipText: herd.tooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) herd.refresh(true)
      else if (buttonCode === Qt.RightButton) root.openDashboard()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") herd.refresh(true)
        else if (t === "d" || t === "D") root.openDashboard()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        Column {
          id: topBlock
          width: parent.width
          spacing: Style.space(12)

          Header { width: parent.width }

          Text {
            textFormat: Text.PlainText
            visible: herd.actionError !== "" || herd.actionMessage !== ""
            width: parent.width
            text: herd.actionError !== "" ? herd.actionError : herd.actionMessage
            color: herd.actionError !== "" ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Text {
            textFormat: Text.PlainText
            visible: !herd.loaded
            width: parent.width
            text: "Checking Herd…"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          ErrorBlock {
            visible: herd.error !== ""
            width: parent.width
          }

          PanelSeparator { visible: root.hasStatus; foreground: root.foreground }

          Column {
            visible: root.hasStatus
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "DATABASES"; foreground: root.foreground; fontFamily: root.fontFamily }

            Text {
              visible: herd.services.length === 0
              text: "No services configured."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }

            Column {
              width: parent.width
              spacing: Style.space(6)

              Repeater {
                model: herd.services
                ServiceRow {
                  required property var modelData
                  required property int index
                  width: parent.width
                  svc: modelData
                  rowIndex: index
                }
              }
            }
          }

          PanelSeparator { visible: root.hasStatus; foreground: root.foreground }

          Column {
            visible: root.hasStatus
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader { text: "RUNTIMES"; foreground: root.foreground; fontFamily: root.fontFamily }

            RuntimeLine {
              label: "PHP"
              versions: herd.phpVersions
              showRunning: true
              emptyText: "No PHP versions installed"
            }

            RuntimeLine {
              label: "NODE"
              versions: herd.nodeVersions
              emptyText: "No Node versions installed"
            }
          }

          PanelSeparator { visible: root.hasStatus; foreground: root.foreground }

          Item {
            visible: root.hasStatus
            width: parent.width
            implicitHeight: sitesHeader.implicitHeight

            PanelSectionHeader {
              id: sitesHeader
              text: "SITES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            PanelSectionHeader {
              anchors.right: parent.right
              text: String(herd.sites.length)
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.hasStatus && herd.sites.length === 0
            width: parent.width
            text: "No sites yet. Park a folder with omarchy-herd park."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }

        ListView {
          id: sitesView
          visible: root.hasStatus && herd.sites.length > 0
          width: parent.width
          height: visible ? Math.min(contentHeight, root.sitesMaxHeight) : 0
          model: herd.sites
          spacing: Style.space(6)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { id: sitesScroll; policy: ScrollBar.AsNeeded }

          delegate: SiteRow {
            required property var modelData
            required property int index
            width: sitesView.width - (sitesView.interactive ? sitesScroll.width + Style.space(4) : 0)
            site: modelData
            rowIndex: root.serviceCount + index
          }
        }

        Column {
          id: bottomBlock
          width: parent.width
          spacing: Style.space(12)

          PanelSeparator { foreground: root.foreground }

          Row {
            id: footer
            width: parent.width
            spacing: Style.space(6)
            readonly property real cellWidth: (width - spacing) / 2

            Button {
              width: footer.cellWidth
              iconText: "󰏌"
              text: "Open dashboard"
              fontSize: Style.font.bodySmall
              iconSize: Style.font.title
              foreground: root.foreground
              fontFamily: root.fontFamily
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              onClicked: root.openDashboard()
            }

            Button {
              width: footer.cellWidth
              iconText: "󰑐"
              iconSpinning: herd.manualRefresh && herd.refreshing
              text: "Refresh"
              fontSize: Style.font.bodySmall
              iconSize: Style.font.title
              foreground: root.foreground
              fontFamily: root.fontFamily
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              onClicked: herd.refresh(true)
            }
          }
        }
      }
    }
  }

  // Hero-style header: glyph, title, health dots, dashboard shortcut.
  component Header: Item {
    implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroButton.implicitHeight)

    Text {
      id: heroIcon
      textFormat: Text.PlainText
      text: root.glyph
      color: herd.loaded && !herd.healthy ? root.urgent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.display
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      id: heroLabels
      anchors.left: heroIcon.right
      anchors.leftMargin: Style.space(14)
      anchors.right: heroButton.left
      anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: "Herd"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Row {
        visible: root.hasStatus
        spacing: Style.space(10)
        HealthDot { label: "WEB"; ok: herd.web.web; tip: ok ? "Caddy is serving .test sites" : "Caddy is not running" }
        HealthDot { label: "DNS"; ok: herd.web.dns; tip: ok ? ".test domains resolve" : ".test domains do not resolve" }
        HealthDot { label: "HTTPS"; ok: herd.web.https; tip: ok ? "Local certificate authority is trusted" : "Local certificate authority is not trusted" }
      }

      Text {
        textFormat: Text.PlainText
        visible: !root.hasStatus
        text: herd.loaded ? "UNAVAILABLE" : "CHECKING"
        color: herd.loaded ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
      }
    }

    Button {
      id: heroButton
      iconText: "󰖟"
      tooltipText: "Open dashboard (d)"
      foreground: root.foreground
      fontFamily: root.fontFamily
      iconSize: Style.font.subtitle * 1.5
      horizontalPadding: Style.space(5)
      verticalPadding: Style.space(2)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      onClicked: root.openDashboard()
    }
  }

  component HealthDot: Item {
    id: healthDot
    property string label: ""
    property bool ok: false
    property string tip: ""
    implicitWidth: dotRow.implicitWidth
    implicitHeight: dotRow.implicitHeight

    Row {
      id: dotRow
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        text: healthDot.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: "●"
        color: healthDot.ok ? root.okColor : root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: healthMouse
      anchors.fill: parent
      hoverEnabled: true
    }

    PanelToolTip {
      visible: healthMouse.containsMouse
      text: healthDot.tip
      fontFamily: root.fontFamily
    }
  }

  component ErrorBlock: CursorSurface {
    bordered: true
    foreground: root.foreground
    implicitHeight: errorColumn.implicitHeight + Style.spacing.rowPaddingX * 2

    Column {
      id: errorColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: herd.error
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: Model.errorHint(herd.error)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  component ServiceRow: CursorSurface {
    id: serviceRow
    property var svc: null
    property int rowIndex: 0
    readonly property bool installed: !!svc && svc.installed !== false
    readonly property bool pending: herd.isPending(svc ? svc.id : "")
    readonly property bool running: herd.isRunning(svc)
    readonly property bool stalled: installed && !pending && svc.enabled === true && !running
    readonly property string meta: {
      if (pending) return herd.pendingAction === "stop" ? "Stopping…" : "Starting…"
      if (stalled) return "Not running · " + Model.serviceAddress(svc)
      return Model.serviceMeta(svc)
    }

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: serviceContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: serviceMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: serviceRow.installed && !herd.busy ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: root.setCursor(serviceRow.rowIndex)
      onClicked: if (!herd.busy) herd.toggleService(serviceRow.svc)
    }

    PanelToolTip {
      visible: serviceMouse.containsMouse && serviceRow.installed && !herd.busy
      text: serviceRow.running ? "Stop" : "Start"
      fontFamily: root.fontFamily
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: Model.serviceIcon(serviceRow.svc)
        color: serviceRow.stalled ? root.urgent : (serviceRow.running ? root.foreground : root.dim)
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Style.space(18)
        horizontalAlignment: Text.AlignHCenter
        opacity: serviceRow.pending ? 0.35 : 1.0

        SequentialAnimation on opacity {
          running: serviceRow.pending
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
        }
      }

      ColumnLayout {
        id: serviceContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: serviceRow.svc ? String(serviceRow.svc.name || serviceRow.svc.id) : ""
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: serviceRow.meta
          color: serviceRow.stalled ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: !!serviceRow.svc && !!serviceRow.svc.version
        text: serviceRow.svc ? String(serviceRow.svc.version || "") : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      // The row owns the click (like Toggle), so the switch only shows state.
      ToggleSwitch {
        visible: serviceRow.installed
        checked: serviceRow.running
        busy: herd.busy
        interactive: false
        foreground: root.foreground
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }

  component RuntimeLine: Item {
    id: runtimeLine
    property string label: ""
    property var versions: []
    property bool showRunning: false
    property string emptyText: ""

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(runtimeLabel.implicitHeight, chips.implicitHeight)

    Text {
      id: runtimeLabel
      textFormat: Text.PlainText
      width: Style.space(48)
      text: runtimeLine.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1.2
      anchors.left: parent.left
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
    }

    Flow {
      id: chips
      anchors.left: runtimeLabel.right
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Repeater {
        model: runtimeLine.versions
        VersionChip {
          required property var modelData
          version: modelData
          showRunning: runtimeLine.showRunning
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: runtimeLine.versions.length === 0
        text: runtimeLine.emptyText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  component VersionChip: BorderSurface {
    id: chip
    property var version: null
    property bool showRunning: false
    readonly property bool isDefault: !!version && version.default === true
    readonly property bool running: !!version && version.running === true
    readonly property string tip: {
      if (!version) return ""
      var parts = [String(version.patch || version.version || "")]
      if (showRunning) parts.push(running ? "PHP-FPM running" : "PHP-FPM stopped")
      if (isDefault) parts.push("default")
      return parts.join(" · ")
    }

    radius: Style.cornerRadius
    color: isDefault ? Style.selectedFillFor(root.foreground, Color.accent) : "transparent"
    borderSpec: Border.controlSpec(isDefault ? "selected" : "normal", root.foreground, Color.accent)
    implicitWidth: chipRow.implicitWidth + Style.space(16)
    implicitHeight: chipRow.implicitHeight + Style.space(8)

    Row {
      id: chipRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Text {
        textFormat: Text.PlainText
        visible: chip.showRunning
        text: "●"
        color: chip.running ? root.okColor : root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: chip.version ? String(chip.version.version || "") : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: chip.isDefault
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        visible: chip.isDefault
        text: "default"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
    }

    PanelToolTip {
      visible: chipMouse.containsMouse && chip.tip !== ""
      text: chip.tip
      fontFamily: root.fontFamily
    }
  }

  component SiteRow: CursorSurface {
    id: siteRow
    property var site: null
    property int rowIndex: 0
    readonly property string url: site ? String(site.url || ("https://" + Model.siteDomain(site))) : ""

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    implicitHeight: siteContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: siteMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(siteRow.rowIndex)
      onClicked: root.openSite(siteRow.site)
    }

    PanelToolTip {
      visible: siteMouse.containsMouse
      text: "Open " + siteRow.url
      fontFamily: root.fontFamily
    }

    RowLayout {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: Model.siteIcon(siteRow.site)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: Style.space(18)
        horizontalAlignment: Text.AlignHCenter
      }

      ColumnLayout {
        id: siteContent
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: Model.siteDomain(siteRow.site)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: Model.siteMeta(siteRow.site)
          visible: text !== ""
          color: !!siteRow.site && siteRow.site.php_installed === false && !!siteRow.site.php ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      Text {
        textFormat: Text.PlainText
        text: "󰏌"
        opacity: siteRow.hasCursor ? 1.0 : 0.0
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }
    }
  }
}
