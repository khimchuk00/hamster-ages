// Headless balance harness. Compiles together with HamsterAges/Core:
//   swiftc -O HamsterAges/Core/*.swift Tools/SimHarness/main.swift -o /tmp/hamster-sim && /tmp/hamster-sim
import Foundation

print(BalanceHarness.report(games: 20))
print("")
print(BalanceHarness.dominanceReport())
