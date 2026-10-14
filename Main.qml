import QtQuick 2.0
import SddmComponents 2.0

// Omarchy SDDM theme with a session selector.
//
// Derived from the stock Omarchy theme (/usr/share/sddm/themes/omarchy/Main.qml).
// The centre of the screen is unchanged: solid background, logo, lock + entry
// art, password rendered as bullet.png sprites in JetBrainsMono Nerd Font.
//
// Added around that:
//   * session selector, top right in a small font -- the convention used by the
//     stock maya theme (elarun puts it in a top bar, left aligned)
//   * user switching, shown only when the machine has more than one account
//   * power controls, bottom centre. Shutdown and reboot are always shown;
//     suspend and hibernate only when the greeter reports them available. That
//     matches elarun, which gates only those two.
//   * clock, top left, and a status line under the password field
//
// Installed as "omarchy-plus", alongside the stock "omarchy" theme rather than
// over it, so omarchy-refresh-sddm (which rewrites themes/omarchy) leaves this
// file alone.
//
// COLOUR NOTE: "#1a1b26" and "#ffffff" below are the same literals
// omarchy-plymouth-set rewrites when it regenerates the *stock* theme from
// /usr/share/omarchy/default/sddm/omarchy/Main.qml (mode=refresh-sddm). Because
// this theme is not that file, those substitutions do not reach here -- edit
// these two values by hand to match a new desktop theme. Every other colour is
// derived from fgColor at runtime, so it follows automatically.

Rectangle {
    id: root
    width: 640
    height: 480
    color: "#1a1b26"

    readonly property color fgColor: "#ffffff"
    readonly property color dimColor: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.55)
    readonly property color faintColor: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.32)
    readonly property color lineColor: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.22)
    readonly property color accentColor: "#f7768e"

    // SDDM 0.21 SessionModel roles, verified empirically. Qt.DisplayRole is NOT
    // implemented -- it returns undefined -- which is also why the stock theme's
    // uwsm-preference scan never actually matched anything.
    //   UserRole+1 dir   +2 file   +3 type (1=X11, 2=Wayland)
    //   UserRole+4 name  +5 exec   +6 comment
    readonly property int sessionNameRole: Qt.UserRole + 4

    readonly property string mono: "JetBrainsMono Nerd Font"
    readonly property int fieldWidth: 286
    readonly property int fieldHeight: 48

    LayoutMirroring.enabled: Qt.locale().textDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    TextConstants { id: textConstants }

    property bool loginFailed: false
    property bool busy: false
    property bool capsLockOn: false
    // Follows SDDM's remembered user when it has one, else the first account.
    property string currentUser: (userModel.lastUser !== "" && userModel.lastUser !== undefined)
                                 ? userModel.lastUser
                                 : root.firstUserName

    // Session index. Honours RememberLastSession=true; the stock theme instead
    // hard-preferred the uwsm session, which made the choice impossible to keep.
    property int sessionIndex: sessionModel.lastIndex

    // ---- multi-monitor -----------------------------------------------------
    Repeater {
        model: screenModel
        delegate: Rectangle {
            x: geometry.x; y: geometry.y
            width: geometry.width; height: geometry.height
            color: root.color
        }
    }

    // userModel.lastUser is empty in some greeter contexts (notably --test-mode),
    // which would attempt a login as "". Capture the first account as a fallback
    // rather than assigning currentUser directly: assigning would break the
    // binding below before SDDM's remembered user had a chance to arrive.
    property string firstUserName: ""

    Repeater {
        model: userModel
        delegate: Item {
            width: 0; height: 0
            visible: false
            Component.onCompleted: if (index === 0) root.firstUserName = model.name
        }
    }

    // Hidden Repeater so the session name can bind to a real `count` property.
    // Reading sessionModel through rowCount()/data() creates no dependency on
    // the model -- those are method calls, not properties -- so the name would
    // go stale if SDDM populated the model after the theme loaded. The stock
    // ComboBox guards the same hazard with its onModelChanged handler.
    //
    // A Repeater, not a hidden ListView: a ListView with no viewport never
    // instantiates its items, so its count stays 0 and the name renders blank.
    Repeater {
        id: sessionProbe
        model: sessionModel
        delegate: Item { width: 0; height: 0; visible: false }
    }

    // ---- date and time, top left -------------------------------------------
    // Same font, size and colour as the session line, mirrored into the
    // opposite corner. A Timer + Text rather than SDDM's Clock component, so
    // the format, font and alignment are all explicit.
    Text {
        id: clockText
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 8
        anchors.leftMargin: 24
        color: root.faintColor
        font.family: root.mono
        font.pixelSize: 14

        Timer {
            interval: 1000
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd dd MMM  HH:mm")
        }
    }

    // ---- session selector, top right ---------------------------------------
    Item {
        id: sessionPicker
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 24
        width: sessionText.width
        height: sessionText.height
        z: 50

        KeyNavigation.tab: password

        // Resolved as a property binding, not a function call: a function
        // declared in this Item is not visible to its children's bindings
        // (ReferenceError: sessionLabel is not defined).
        property string sessionName: {
            // sessionProbe.count is the dependency that makes this re-run once
            // SDDM has populated the model; rowCount() is the fallback for the
            // moment before the probe has built its delegates.
            var total = sessionProbe.count > 0 ? sessionProbe.count : sessionModel.rowCount()
            if (total === 0)
                return textConstants.session
            var i = root.sessionIndex
            if (i < 0 || i >= total)
                return textConstants.session
            var n = sessionModel.data(sessionModel.index(i, 0), root.sessionNameRole)
            return (n === undefined || n === "") ? textConstants.session : n
        }

        Text {
            id: sessionText
            anchors.right: parent.right
            text: sessionPicker.sessionName + " ▾"
            color: sessionMouse.containsMouse ? root.fgColor : root.faintColor
            font.family: root.mono
            font.pixelSize: 14
        }

        MouseArea {
            id: sessionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sessionList.visible = !sessionList.visible
        }

        Rectangle {
            id: sessionList
            visible: false
            anchors.top: parent.bottom
            anchors.topMargin: 6
            anchors.right: parent.right
            width: 280
            height: Math.min((sessionProbe.count > 0 ? sessionProbe.count
                                                     : sessionModel.rowCount()) * 30 + 8, 220)
            color: root.color
            border.color: root.lineColor
            border.width: 1
            z: 60

            ListView {
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: sessionModel
                delegate: Text {
                    width: sessionList.width - 8
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: model.name
                    color: (index === root.sessionIndex) ? root.accentColor
                         : sessionItemMouse.containsMouse ? root.fgColor : root.dimColor
                    font.family: root.mono
                    font.pixelSize: 14

                    MouseArea {
                        id: sessionItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.sessionIndex = index
                            sessionList.visible = false
                            password.focus = true
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            root.loginFailed = false
            root.busy = false
        }
        function onLoginFailed() {
            root.loginFailed = true
            root.busy = false
            password.text = ""
            password.focus = true
        }
        function onInformationMessage(message) {
            root.busy = false
            statusText.text = message
        }
    }

    // ---- main column -------------------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: 22

        Image {
            id: logo
            source: "logo.png"
            width: Math.min(sourceSize.width, root.width * 0.8)
            height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ---- user switching ------------------------------------------------
        // Only rendered when there is more than one account to choose from, so
        // a single-user machine looks exactly like the stock theme.
        Item {
            id: userPicker
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldWidth
            height: visible ? 22 : 0
            visible: userModel.rowCount() > 1
            z: 30

            Text {
                anchors.centerIn: parent
                text: root.currentUser + "  ▾"
                color: userPickerMouse.containsMouse ? root.dimColor : root.faintColor
                font.family: root.mono
                font.pixelSize: 14
            }

            MouseArea {
                id: userPickerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: userList.visible = !userList.visible
            }

            Rectangle {
                id: userList
                visible: false
                anchors.top: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: root.fieldWidth
                height: Math.min(userModel.rowCount() * 30 + 8, 200)
                color: root.color
                border.color: root.lineColor
                border.width: 1
                z: 40

                ListView {
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    model: userModel
                    delegate: Text {
                        width: userList.width - 8
                        height: 30
                        verticalAlignment: Text.AlignVCenter
                        text: model.name
                        color: userMouse.containsMouse ? root.fgColor : root.dimColor
                        font.family: root.mono
                        font.pixelSize: 14

                        MouseArea {
                            id: userMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentUser = parent.text
                                userList.visible = false
                                password.focus = true
                            }
                        }
                    }
                }
            }
        }

        // ---- username -------------------------------------------------------
        // Editable and prefilled with the last user, matching the maldives and
        // elarun convention. Without this there is no way to log in as any
        // account other than the remembered one.
        //
        // No icon: the theme ships no user glyph, and inventing one risks a
        // Nerd Font codepoint that does not render. The empty Item below holds
        // the width of the lock icon so this box lines up with the password box.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15

            Item { width: 34; height: 38 }

            Item {
                width: root.fieldWidth
                height: root.fieldHeight

                Image {
                    anchors.centerIn: parent
                    source: "entry.png"
                }

                TextInput {
                    id: username
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: root.mono
                    font.pixelSize: 20
                    font.letterSpacing: 3
                    color: root.dimColor
                    selectionColor: root.accentColor
                    selectedTextColor: root.color
                    text: root.currentUser

                    // Write back only on a real difference, so the initial
                    // binding pass cannot break currentUser's binding to
                    // userModel.lastUser before SDDM supplies it.
                    onTextChanged: if (text !== root.currentUser) root.currentUser = text

                    KeyNavigation.tab: password
                    KeyNavigation.backtab: sessionPicker

                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.tryLogin()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // ---- password entry -------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 15

            Image {
                source: root.loginFailed ? "lock-failed.png" : "lock.png"
                width: 34
                height: 38
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: root.fieldWidth
                height: root.fieldHeight

                Image {
                    id: entry
                    source: root.loginFailed ? "entry-failed.png" : "entry.png"
                    anchors.centerIn: parent
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: Math.min(password.text.length, 21)
                        Image { source: "bullet.png"; width: 7; height: 7 }
                    }
                }

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    font.family: root.mono
                    font.pixelSize: 24
                    font.letterSpacing: 5
                    passwordCharacter: "•"
                    color: "transparent"
                    selectionColor: "transparent"
                    selectedTextColor: "transparent"
                    cursorDelegate: Item {}
                    focus: true

                    KeyNavigation.tab: powerRow
                    KeyNavigation.backtab: sessionPicker

                    onTextChanged: {
                        root.loginFailed = false
                        statusText.text = ""
                    }

                    // Caps-lock state is not queryable from pure QML, so track
                    // the key itself. Accurate for toggling at the greeter;
                    // it cannot see a lock already on before SDDM started.
                    Keys.onPressed: function (event) {
                        if (event.key === Qt.Key_CapsLock) {
                            root.capsLockOn = !root.capsLockOn
                            event.accepted = false
                        }
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.tryLogin()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // ---- status line ----------------------------------------------------
        Text {
            id: statusText
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldWidth
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: root.loginFailed ? root.accentColor : root.faintColor
            font.family: root.mono
            font.pixelSize: 13
            // No idle prompt: textConstants.prompt reads "Enter your username
            // and password", but this theme has no username field. The stock
            // Omarchy theme shows no idle text either.
            text: root.capsLockOn ? textConstants.capslockWarning
                : root.busy ? "authenticating…"
                : ""
        }

        // The keyboard layout selector (SDDM's stock LayoutBox) was removed.
        // It draws its own chrome -- a blue focus highlight and a white arrow
        // button -- that no property can override, so it could never match this
        // theme's entry.png fields. This machine has a single layout ("us"), so
        // it offered nothing either. Re-add it here if you ever configure
        // multiple layouts in ~/.config/hypr/input.lua.

    }

    // ---- power actions, bottom right ---------------------------------------
    // Shutdown and reboot are never gated (matching elarun); only suspend and
    // hibernate depend on what the greeter reports as available.
    Row {
        id: powerRow
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 8
        anchors.rightMargin: 24
        spacing: 18

        Repeater {
            model: [
                { label: "shutdown",  show: true,               fn: "powerOff" },
                { label: "reboot",    show: true,               fn: "reboot" },
                { label: "suspend",   show: sddm.canSuspend,    fn: "suspend" },
                { label: "hibernate", show: sddm.canHibernate,  fn: "hibernate" }
            ]

            delegate: Text {
                visible: modelData.show
                text: modelData.label
                color: powerMouse.containsMouse ? root.accentColor : root.faintColor
                font.family: root.mono
                font.pixelSize: 14

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runPower(modelData.fn)
                }
            }
        }
    }

    // Explicit dispatch: bracket-style sddm[name]() is not reliable for
    // QObject methods exposed to QML.
    function runPower(fn) {
        if (fn === "powerOff")       sddm.powerOff()
        else if (fn === "reboot")    sddm.reboot()
        else if (fn === "suspend")   sddm.suspend()
        else if (fn === "hibernate") sddm.hibernate()
    }

    function tryLogin() {
        root.busy = true
        statusText.text = "authenticating…"
        sddm.login(root.currentUser, password.text, root.sessionIndex)
    }

    Component.onCompleted: {
        // Stock omarchy preferred the uwsm session unconditionally. Only fall
        // back to it when SDDM has no remembered session to restore.
        if (root.sessionIndex < 0) {
            for (var i = 0; i < sessionModel.rowCount(); i++) {
                var n = (sessionModel.data(sessionModel.index(i, 0), root.sessionNameRole) || "").toString()
                if (n.indexOf("uwsm") !== -1) {
                    root.sessionIndex = i
                    break
                }
            }
        }
        password.forceActiveFocus()
    }
}
