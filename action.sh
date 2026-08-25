#!/system/bin/sh
# Open the module WebUI from a supported host application.

if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    if am start -n io.github.a13e300.ksuwebui/.WebUIActivity \
        -e id bluelightfilter >/dev/null 2>&1; then
        exit 0
    fi
    printf '%s\n' 'BlueLightFIlter: KSUWebUIStandalone could not open the module.' >&2
    exit 1
fi

if pm path com.dergoogler.mmrl >/dev/null 2>&1; then
    if am start -n com.dergoogler.mmrl/.ui.activity.webui.WebUIActivity \
        -e MOD_ID bluelightfilter >/dev/null 2>&1; then
        exit 0
    fi
    printf '%s\n' 'BlueLightFIlter: MMRL could not open the module.' >&2
    exit 1
fi

printf '%s\n' 'BlueLightFIlter: install KSUWebUIStandalone or MMRL to use the WebUI.' >&2
am start -a android.intent.action.VIEW \
    -d https://github.com/5ec1cff/KsuWebUIStandalone/releases >/dev/null 2>&1
