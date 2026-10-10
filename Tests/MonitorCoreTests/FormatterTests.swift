import Testing
@testable import MonitorCore

@Suite struct FormatterTests {
    @Test func bytes() {
        #expect(ByteFormatter.string(0 as UInt64) == "0 B")
        #expect(ByteFormatter.string(999 as UInt64) == "999 B")
        #expect(ByteFormatter.string(1_500 as UInt64) == "1.50 KB")
        #expect(ByteFormatter.string(25_000_000 as UInt64) == "25.0 MB")
        #expect(ByteFormatter.string(8_589_934_592 as UInt64) == "8.59 GB")
        #expect(ByteFormatter.string(-5.0) == "0 B")
    }

    @Test func rates() {
        #expect(RateFormatter.string(bytesPerSecond: 2_300_000) == "2.30 MB/s")
        #expect(RateFormatter.percent(23.4) == "23 %")
    }

    @Test func durations() {
        #expect(DurationFormatter.uptime(3_661) == "1:01:01")
        #expect(DurationFormatter.uptime(90_061) == "1d 1:01:01")
        #expect(DurationFormatter.short(8_100) == "2h 15m")
        #expect(DurationFormatter.short(300) == "5m")
    }
}
