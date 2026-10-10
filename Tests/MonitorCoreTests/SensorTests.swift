import Testing
@testable import MonitorCore

@Suite struct SensorTests {
    @Test func decodesSMCTypes() {
        // 41.5 as little-endian IEEE float = 0x42260000
        #expect(SMC.decode(.init(type: "flt ", bytes: [0x00, 0x00, 0x26, 0x42])) == 41.5)
        #expect(SMC.decode(.init(type: "ui8 ", bytes: [2])) == 2)
        #expect(SMC.decode(.init(type: "ui16", bytes: [0x01, 0x00])) == 256)
        #expect(SMC.decode(.init(type: "sp78", bytes: [0x1E, 0x80])) == 30.5)
        #expect(SMC.decode(.init(type: "fpe2", bytes: [0x0B, 0xB8])) == 750)
        #expect(SMC.decode(.init(type: "????", bytes: [1, 2])) == nil)
    }

    @Test func fourCharCodesRoundTrip() {
        #expect(SMC.string(SMC.code("TC0P")) == "TC0P")
        #expect(SMC.code("flt ") == 0x666C7420)
    }

    @Test func groupsSensorKeys() {
        #expect(SensorReader.group(forKey: "Tp01") == .cpu)
        #expect(SensorReader.group(forKey: "Tg0D") == .gpu)
        #expect(SensorReader.group(forKey: "TB0T") == .battery)
        #expect(SensorReader.group(forKey: "TH0x") == .other)
    }

    @Test func sensorAggregates() {
        let s = SensorSample(timestamp: 0, temperatures: [
            .init(key: "Tp01", name: "a", group: .cpu, celsius: 40),
            .init(key: "Tp02", name: "b", group: .cpu, celsius: 60),
            .init(key: "TB0T", name: "c", group: .battery, celsius: 90)], fans: [])
        #expect(s.cpuAverage == 50)
        #expect(s.cpuMax == 60)
    }
}
