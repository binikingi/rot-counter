// Run: swiftc Shared/Elapsed.swift Tests/main.swift -o /tmp/rotcheck && /tmp/rotcheck
import Foundation

let start = Date(timeIntervalSince1970: 0)
let e = Elapsed(since: start, now: start.addingTimeInterval(3 * 86_400 + 3_661))
assert(e.days == 3)
assert(e.dayStart == start.addingTimeInterval(3 * 86_400))
assert(e.nextDay == start.addingTimeInterval(4 * 86_400))
assert(Elapsed(since: start, now: start.addingTimeInterval(86_399)).days == 0)
assert(Elapsed(since: start, now: start.addingTimeInterval(-10)).days == 0)  // clock skew
print("ok")
