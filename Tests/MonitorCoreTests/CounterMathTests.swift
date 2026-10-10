import Testing
@testable import MonitorCore

@Suite struct CounterMathTests {
    @Test func counterDelta() {
        #expect(CounterMath.delta(prev: 100, cur: 250) == 150)
        #expect(CounterMath.delta(prev: 250, cur: 100) == 0)   // reset => 0
    }

    @Test func thirtyTwoBitWrap() {
        #expect(CounterMath.delta32(prev: UInt32.max - 5, cur: 4) == 10)
    }

    @Test func rateUsesElapsedTime() {
        #expect(CounterMath.rate(delta: 3_000, seconds: 1.5) == 2_000)
        #expect(CounterMath.rate(delta: 3_000, seconds: 0) == 0)
    }

    @Test func cpuUsage() {
        let prev = CoreTicks(user: 100, system: 50, idle: 800, nice: 0)
        let cur = CoreTicks(user: 130, system: 60, idle: 850, nice: 10)
        let u = CPUMath.usage(prev: prev, cur: cur)  
        #expect(abs(u.user - 40) < 0.001)
        #expect(abs(u.system - 10) < 0.001)
        #expect(abs(u.idle - 50) < 0.001)
    }

    @Test func cpuUsageHandlesWrapAndNoChange() {
        let a = CoreTicks(user: UInt32.max - 1, system: 0, idle: 0, nice: 0)
        let b = CoreTicks(user: 8, system: 0, idle: 0, nice: 0)
        #expect(abs(CPUMath.usage(prev: a, cur: b).user - 100) < 0.001)
        #expect(CPUMath.usage(prev: a, cur: a).idle == 100)
    }

    @Test func memoryComposition() {
        let pages = MemoryPages(internalPages: 300, purgeable: 50, external: 100, wired: 80, compressor: 20)
        let m = MemoryMath.compose(pages: pages, pageSize: 16_384, total: 1_000 * 16_384)
        #expect(m.app == 250 * 16_384)
        #expect(m.used == (250 + 80 + 20) * 16_384)
        #expect(m.cached == 150 * 16_384)
        #expect(m.free == (1_000 - 350 - 150) * 16_384)
        #expect(m.available == (1_000 - 350) * 16_384)
    }

    @Test func memoryNeverUnderflows() {
        let pages = MemoryPages(internalPages: 10, purgeable: 20, external: 0, wired: 5000, compressor: 0)
        let m = MemoryMath.compose(pages: pages, pageSize: 1, total: 100)
        #expect(m.app == 0)
        #expect(m.free == 0)
        #expect(m.available == 0)
    }

    @Test func interfaceFiltering() {
        #expect(NetworkFilter.countsTowardTotal("en0"))
        for n in ["lo0", "utun3", "awdl0", "llw0", "bridge100", "anpi0", "ap1", "gif0", "stf0"] {
            #expect(!NetworkFilter.countsTowardTotal(n))
        }
        #expect(NetworkFilter.isPhysical("en1"))
        #expect(!NetworkFilter.isPhysical("utun0"))
    }
}
