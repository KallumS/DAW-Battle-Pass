# 0019 - Typing is counted, never recorded

"Each letter typed gives experience" means watching the keyboard in other
apps. A listen-only `CGEvent` tap does it, under the Input Monitoring
permission (narrower than Accessibility, and it can't change anything).

The tap keeps three numbers and nothing else: letters (letters and digits),
words (a letter run ended by a space or punctuation; apostrophes and hyphens
stay inside a word) and key presses. Command and Control shortcuts and
auto-repeat don't count. Password fields never reach a tap at all. The
numbers are only credited when the app in front is one of her writing apps
(a list she controls; or every app, if she switches that on), and the app's
own window never counts.

Without the permission the app still works: the clock runs on "something was
touched in a writing app", read from the system's idle time, which needs no
permission.
