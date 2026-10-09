# 036-holidays-auto.sh - Holidays are Automatic or None
#
# Settings › Dashboard › Calendar no longer lists a country: "br" becomes
# "auto", which shows Brazil's holidays when the time zone or the language is
# Brazilian.

lyne_state_set 'if .dashboard.holidays == "br" then .dashboard.holidays = "auto" else . end' || true
return 0
